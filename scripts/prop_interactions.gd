extends Node
## Companion controls for merged HI3D meshes. Original imported meshes remain intact.
signal control_changed(control_id: String, value: float)
var lab: Control
var controls: Dictionary = {}
var states: Dictionary = {}
var bound: Dictionary = {}
var active: String = ""
var scan_elapsed: float = 0.0
var lamp_light: OmniLight3D
var focus_targets: Dictionary = {}

func setup(host: Control) -> void:
	lab = host
	process_priority = 1

func _process(delta: float) -> void:
	if lab == null:
		return
	scan_elapsed += delta
	if scan_elapsed >= 0.5:
		scan_elapsed = 0.0
		_bind_props()
	var hit: Dictionary = _pick(lab.get_global_mouse_position())
	if not hit.is_empty():
		var id: String = str((hit["collider"] as Node).get_meta("prop_control", ""))
		if controls.has(id):
			lab.image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			lab.status.text = str(controls[id]["label"])
	elif active.is_empty():
		var focus_hit: Dictionary = _pick(lab.get_global_mouse_position(), 8)
		if not focus_hit.is_empty():
			var target: Node3D = (focus_hit["collider"] as Node).get_meta("focus_target") as Node3D
			lab.image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			lab.status.text = "%s · 点击聚焦" % str(focus_targets[target.get_instance_id()]["label"])
	if not active.is_empty() and controls.has(active):
		lab.status.text = "%s · %d%%" % [controls[active]["label"], roundi(float(states[active]) * 100)]

func _bind_props() -> void:
	var props: Node = lab.desk.find_child("GeneratedProps", true, false)
	if props == null:
		return
	for child: Node in props.get_children():
		if child is Node3D:
			_register_focus(child as Node3D)
	for item: String in ["Radio", "Recorder", "Lamp"]:
		var holder: Node3D = props.get_node_or_null(item) as Node3D
		if holder == null or bound.has(holder.get_instance_id()):
			continue
		var bounds: AABB = _bounds(holder)
		if bounds.size.length() < 0.001:
			continue
		bound[holder.get_instance_id()] = true
		if item == "Radio":
			_add(holder, bounds, "radio.power", "收音机电源 · 点击", Vector3(0.51, 0.19, 0.99), false)
			_add(holder, bounds, "radio.volume", "音量 · 左右拖动", Vector3(0.65, 0.19, 0.99), true)
			_add(holder, bounds, "radio.tuning", "调谐 · 左右拖动", Vector3(0.78, 0.19, 0.99), true)
		elif item == "Recorder":
			_add(holder, bounds, "recorder.play", "播放 / 暂停 · 点击", Vector3(0.25, 0.25, 0.96), false)
			_add(holder, bounds, "recorder.stop", "停止 · 点击", Vector3(0.36, 0.25, 0.96), false)
			_add(holder, bounds, "recorder.level", "录音机电平 · 左右拖动", Vector3(0.79, 0.25, 1.0), true)
		else:
			_add(holder, bounds, "lamp.power", "台灯开关 · 点击", Vector3(0.5, 0.08, 0.8), false)
			lamp_light = OmniLight3D.new()
			lamp_light.name = "InteractiveLampLight"
			lamp_light.position = bounds.position + bounds.size * Vector3(0.65, 0.65, 0.55)
			lamp_light.light_color = Color("ffd6a0")
			lamp_light.light_energy = 0.8
			lamp_light.omni_range = 5.0
			holder.add_child(lamp_light)
			states["lamp.power"] = 1.0

func _register_focus(holder: Node3D) -> void:
	if focus_targets.has(holder.get_instance_id()):
		return
	var bounds: AABB = _bounds(holder)
	if bounds.size.length() < 0.001:
		return
	var labels: Dictionary = {"Keyboard": "键盘", "Radio": "收音机", "Lamp": "台灯", "Recorder": "录音机"}
	focus_targets[holder.get_instance_id()] = {"bounds": bounds, "label": labels.get(str(holder.name), str(holder.name))}
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "FocusHitbox"
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = bounds.get_center()
	body.set_meta("focus_target", holder)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = bounds.size
	collider.shape = shape
	body.add_child(collider)
	holder.add_child(body)

func focus_item(holder: Node3D) -> void:
	cancel()
	lab.end_screen_editing()
	var bounds: AABB = holder.global_transform * (focus_targets[holder.get_instance_id()]["bounds"] as AABB)
	var pitch: float = 55.0 if str(holder.name) == "Keyboard" else 10.0
	lab.camera.focus_bounds(bounds, str(holder.name), pitch)
	for button: Button in lab.view_buttons:
		button.set_pressed_no_signal(false)

func _bounds(holder: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for node: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var box: AABB = (holder.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func _add(holder: Node3D, bounds: AABB, id: String, label: String, normalized: Vector3, knob: bool) -> void:
	var pivot: Node3D = Node3D.new()
	pivot.name = id.replace(".", "_")
	pivot.position = bounds.position + bounds.size * normalized
	holder.add_child(pivot)
	var radius: float = bounds.size.x * (0.038 if knob else 0.041)
	var cap: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.06
	mesh.height = radius * 0.32
	cap.mesh = mesh
	cap.rotation_degrees.x = 90.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color("f5cf9e")
	mat.roughness = 0.45
	cap.material_override = mat
	pivot.add_child(cap)
	if knob:
		var mark: MeshInstance3D = MeshInstance3D.new()
		var bar: BoxMesh = BoxMesh.new()
		bar.size = Vector3(radius * 0.14, radius * 0.60, radius * 0.08)
		mark.mesh = bar
		mark.position = Vector3(0, radius * 0.40, radius * 0.20)
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.albedo_color = Color("315e61")
		mark.material_override = ink
		pivot.add_child(mark)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.set_meta("prop_control", id)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(radius * 2.6, radius * 2.6, radius * 1.2)
	collider.shape = shape
	body.add_child(collider)
	pivot.add_child(body)
	controls[id] = {"pivot": pivot, "rest": pivot.position, "knob": knob, "label": label}
	states[id] = 0.5 if knob else 0.0

func _pick(at: Vector2, mask: int = 4) -> Dictionary:
	if not lab.image.get_global_rect().has_point(at):
		return {}
	var pixel: Vector2 = lab.image_uv(at) * Vector2(lab.scene_view.size)
	var origin: Vector3 = lab.camera.project_ray_origin(pixel)
	var ray: Vector3 = lab.camera.project_ray_normal(pixel)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + ray * 40, mask)
	return lab.scene_view.find_world_3d().direct_space_state.intersect_ray(query)

func _unhandled_input(event: InputEvent) -> void:
	if lab != null and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE and not lab.camera.focused_item.is_empty():
		lab.select_view(4)
		get_viewport().set_input_as_handled()
		return
	if lab == null or not event is InputEventMouseButton:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	var hit: Dictionary = _pick(button.position)
	if hit.is_empty():
		var focus_hit: Dictionary = _pick(button.position, 8)
		if not focus_hit.is_empty():
			focus_item((focus_hit["collider"] as Node).get_meta("focus_target") as Node3D)
			get_viewport().set_input_as_handled()
		return
	active = str((hit["collider"] as Node).get_meta("prop_control", ""))
	lab.end_screen_editing()
	if not bool(controls[active]["knob"]):
		var pivot: Node3D = controls[active]["pivot"]
		pivot.position.z -= 0.025
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if active.is_empty():
		return
	if event is InputEventMouseMotion and bool(controls[active]["knob"]):
		set_value(active, float(states[active]) + (event as InputEventMouseMotion).relative.x / 180.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			var hit: Dictionary = _pick(button.position)
			var released_on: String = "" if hit.is_empty() else str((hit["collider"] as Node).get_meta("prop_control", ""))
			if not bool(controls[active]["knob"]) and released_on == active:
				set_value(active, 1.0 - float(states[active]))
			cancel()
			get_viewport().set_input_as_handled()

func set_value(id: String, value: float) -> void:
	if not controls.has(id):
		return
	states[id] = clampf(value, 0, 1)
	if bool(controls[id]["knob"]):
		(controls[id]["pivot"] as Node3D).rotation.z = lerpf(deg_to_rad(135), deg_to_rad(-135), float(states[id]))
	if id == "lamp.power" and lamp_light != null:
		lamp_light.visible = value > 0.5
	if id == "recorder.stop":
		states["recorder.play"] = 0.0
	control_changed.emit(id, float(states[id]))

func cancel() -> void:
	if controls.has(active):
		(controls[active]["pivot"] as Node3D).position = controls[active]["rest"]
	active = ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel()
