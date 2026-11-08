extends Node
## Companion controls for merged HI3D meshes. Original imported meshes remain intact.
signal control_changed(control_id: String, value: float)
const RecorderReels: Script = preload("res://scripts/recorder_reels.gd")
var lab: Control
var controls: Dictionary = {}
var states: Dictionary = {}
var bound: Dictionary = {}
var active: String = ""
var scan_elapsed: float = 0.0
var lamp_light: OmniLight3D
var focus_targets: Dictionary = {}
var audio: Node
var tape_mode: String = "stop"
var reel_motion: Node3D
var key_bindings: Dictionary = {}
var key_motions: Dictionary = {}
const KEY_ROWS: Array[String] = ["1234567890-=", "QWERTYUIOP[]", "ASDFGHJKL;'\\", "ZXCVBNM,./"]

func setup(host: Control) -> void:
	lab = host
	audio = host.get("control_audio") as Node
	process_priority = 1
	lab.physical_key_changed.connect(_physical_key_changed)
	call_deferred("_bind_props")

func _process(delta: float) -> void:
	if lab == null:
		return
	if _modal():
		cancel()
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
			lab.status.text = _control_label(id)
	elif active.is_empty():
		var focus_hit: Dictionary = _pick(lab.get_global_mouse_position(), 8)
		if not focus_hit.is_empty():
			var target: Node3D = (focus_hit["collider"] as Node).get_meta("focus_target") as Node3D
			lab.image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			lab.status.text = "%s · 点击聚焦" % str(focus_targets[target.get_instance_id()]["label"])
	if not active.is_empty() and controls.has(active):
		lab.status.text = "%s · %d%%" % [controls[active]["label"], roundi(float(states[active]) * 100)]

func _bind_props() -> void:
	var legacy_keyboard: Node3D = lab.desk.get_node_or_null("Computer/Keyboard") as Node3D
	if legacy_keyboard != null:
		_register_focus(legacy_keyboard)
		_bind_keyboard(legacy_keyboard)
	_bind_computer()
	var props: Node = lab.desk.find_child("GeneratedProps", true, false)
	if props == null:
		return
	for child: Node in props.get_children():
		# The computer keeps its screen and camera-region interaction routes.
		if str(child.name) == "Computer":
			_register_focus(child as Node3D, false)
			continue
		if child is Node3D and (child as Node3D).is_visible_in_tree():
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
			_add(holder, bounds, "recorder.rewind", "倒带 · 点击", Vector3(0.55, 0.25, 0.96), false)
			_add(holder, bounds, "recorder.record", "录音监听 · 点击", Vector3(0.66, 0.25, 0.96), false)
			_add(holder, bounds, "recorder.level", "录音机电平 · 左右拖动", Vector3(0.79, 0.25, 1.0), true)
			reel_motion = RecorderReels.new()
			reel_motion.name = "RecorderReels"
			holder.add_child(reel_motion)
			reel_motion.call("setup", holder, bounds)
		else:
			_add(holder, bounds, "lamp.power", "台灯开关 · 点击", Vector3(0.22, 0.45, 0.73), false, 0.027)
			lamp_light = preload("res://scripts/lamp_pulse.gd").new()
			lamp_light.name = "InteractiveLampLight"
			lamp_light.position = bounds.position + bounds.size * Vector3(0.68, 0.70, 0.68)
			lamp_light.light_color = Color("ffd6a0")
			lamp_light.light_energy = 0.8
			lamp_light.omni_range = 5.0
			holder.add_child(lamp_light)
			lamp_light.call("attach_bulb", holder, bounds.position + bounds.size * Vector3(0.68, 0.70, 0.68), bounds.size.x * 0.09)
			states["lamp.power"] = 1.0
			_refresh_button("lamp.power")
		if item == "Radio":
			states["radio.volume"] = 0.55
			_apply_knob("radio.volume")
			_apply_knob("radio.tuning")
		elif item == "Recorder":
			states["recorder.level"] = 0.6
			_apply_knob("recorder.level")
	if props.has_node("Computer") and not controls.has("computer.power"):
		var computer: Node3D = props.get_node("Computer") as Node3D
		var bounds: AABB = _bounds(computer)
		_add(computer, bounds, "computer.power", "电脑电源 · 点击", Vector3(0.516, 0.138, 0.941), false, 0.018)
		_add(computer, bounds, "computer.palette", "屏幕色彩 · 点击切换", Vector3(0.562, 0.138, 0.935), false, 0.018)
		_add(computer, bounds, "computer.lock", "锁屏 · 点击", Vector3(0.611, 0.139, 0.929), false, 0.018)
		states["computer.power"] = 1.0 if lab.desk.powered else 0.0

func _register_focus(holder: Node3D, create_body: bool = true) -> void:
	if focus_targets.has(holder.get_instance_id()):
		return
	var bounds: AABB = _bounds(holder)
	if bounds.size.length() < 0.001:
		return
	var labels: Dictionary = {"Keyboard": "键盘", "Radio": "收音机", "Lamp": "台灯", "Recorder": "录音机", "OrigamiBird": "折纸鸟", "CardHolder": "卡片架", "Rocket": "火箭摆件", "WallShelf": "搁板", "BinderPink": "粉色文件夹"}
	focus_targets[holder.get_instance_id()] = {"bounds": bounds, "label": labels.get(str(holder.name), str(holder.name))}
	if not create_body:
		return
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
	# Inspect the recorder from its left shoulder so the foreground rocket clears its dial.
	lab.camera.focus_bounds(bounds, str(holder.name), 32.0 if str(holder.name) == "Recorder" else pitch, -18.0 if str(holder.name) == "Recorder" else 0.0)
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

func _add(holder: Node3D, bounds: AABB, id: String, label: String, normalized: Vector3, knob: bool, radius_ratio: float = 0.0) -> void:
	var pivot: Node3D = Node3D.new()
	pivot.name = id.replace(".", "_")
	pivot.position = bounds.position + bounds.size * normalized
	holder.add_child(pivot)
	var radius: float = bounds.size.x * (radius_ratio if radius_ratio > 0 else (0.038 if knob else 0.041))
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
	controls[id] = {"pivot": pivot, "rest": pivot.position, "knob": knob, "label": label,
		"body": body, "holder": holder, "axis": Vector3.FORWARD, "depth": minf(0.025, radius * 0.25), "material": mat}
	states[id] = 0.5 if knob else 0.0
	if knob:
		_apply_knob(id)

func _bind_computer() -> void:
	if controls.has("computer.knob"):
		return
	var imported: Node3D = lab.desk.get_node_or_null("GeneratedProps/Computer") as Node3D
	if imported == null:
		return
	var knob: Node3D = lab.desk.tuning_knob
	for node: Node in knob.find_children("*", "CollisionObject3D", true, false):
		(node as CollisionObject3D).collision_layer = 0
	_add_existing(knob, "computer.knob", "屏幕亮度 · 左右拖动", Vector3(0.24, 0.24, 0.20), true, imported)
	states["computer.knob"] = 0.7
	_apply_knob("computer.knob")
	# The legacy tray is hidden by the imported computer and must not remain clickable.
	if not lab.desk.tray.is_visible_in_tree() or not (lab.desk.tray.get_node("TrayFace") as Node3D).is_visible_in_tree():
		for node: Node in lab.desk.tray.find_children("*", "CollisionObject3D", true, false):
			(node as CollisionObject3D).collision_layer = 0

func _add_existing(pivot: Node3D, id: String, label: String, dimensions: Vector3, knob: bool, holder: Node3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ControlHit"
	body.collision_layer = 4
	body.collision_mask = 0
	body.set_meta("prop_control", id)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	pivot.add_child(body)
	controls[id] = {"pivot": pivot, "rest": pivot.position, "knob": knob, "label": label,
		"body": body, "holder": holder, "axis": Vector3.DOWN if id.begins_with("keyboard.") else Vector3.FORWARD, "depth": 0.035}
	states[id] = 0.0

func _bind_keyboard(holder: Node3D) -> void:
	if controls.has("keyboard.space"):
		return
	var font: Font = preload("res://scripts/terminal_font.gd").create_font(true)
	for child: Node in holder.get_children():
		var key: MeshInstance3D = child as MeshInstance3D
		if key == null or not (str(key.name).begins_with("Key_") or str(key.name) == "SpaceBar"):
			continue
		var id: String = "keyboard.space" if str(key.name) == "SpaceBar" else "keyboard." + str(key.name).to_lower()
		var text: String = "SPACE"
		var code: int = KEY_SPACE
		if id != "keyboard.space":
			var parts: PackedStringArray = str(key.name).split("_")
			var row: int = int(parts[1])
			var column: int = int(parts[2])
			if column < KEY_ROWS[row].length():
				text = KEY_ROWS[row].substr(column, 1)
				code = text.unicode_at(0)
			else:
				code = KEY_BACKSPACE if row == 3 and column == 10 else KEY_ENTER
				text = "BS" if code == KEY_BACKSPACE else "RET"
		_add_existing(key, id, "键盘 %s · 点击" % text, key.get_aabb().size + Vector3(0.025, 0.025, 0.025), false, holder)
		controls[id]["keycode"] = code
		controls[id]["unicode"] = KEY_SPACE if id == "keyboard.space" else (text.unicode_at(0) if text.length() == 1 else 0)
		key_bindings[code] = id
		var glyph: Label3D = Label3D.new()
		glyph.name = "KeyLegend"
		glyph.text = text
		glyph.font = font
		glyph.font_size = 18
		glyph.pixel_size = 0.0020 if text.length() < 3 else 0.0015
		glyph.outline_size = 0
		glyph.modulate = Color("315e61")
		glyph.rotation_degrees.x = -90.0
		glyph.position.y = key.get_aabb().end.y + 0.002
		key.add_child(glyph)

func _modal() -> bool:
	return lab.file_reader != null and lab.file_reader.visible

func _control_label(id: String) -> String:
	if id.begins_with("keyboard.") and lab.camera.focused_item != "Keyboard":
		return "键盘 · 点击聚焦"
	if id == "radio.power":
		return "收音机 · %s" % ("已开启" if float(states[id]) > 0.5 else "已关闭")
	if id == "recorder.record":
		return "录音监听 · %s" % ("正在监听演示音轨" if tape_mode == "record" else "点击开启演示音轨")
	return str(controls[id]["label"])

func _pick(at: Vector2, mask: int = 4) -> Dictionary:
	if not lab.image.get_global_rect().has_point(at):
		return {}
	var pixel: Vector2 = lab.image_uv(at) * Vector2(lab.scene_view.size)
	var origin: Vector3 = lab.camera.project_ray_origin(pixel)
	var ray: Vector3 = lab.camera.project_ray_normal(pixel)
	var query_mask: int = mask | 16 if mask == 8 else mask
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + ray * 40, query_mask)
	var result: Dictionary = lab.scene_view.find_world_3d().direct_space_state.intersect_ray(query)
	if mask == 8 and not result.is_empty() and not (result["collider"] as Node).has_meta("focus_target"):
		return {}
	return result

func _unhandled_input(event: InputEvent) -> void:
	if lab == null or _modal():
		cancel()
		return
	if lab != null and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE and not lab.camera.focused_item.is_empty():
		lab.select_view(4)
		get_viewport().set_input_as_handled()
		return
	if lab == null or not event is InputEventMouseButton:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	# Computer camera presets do not use focused_item. Dismiss them before
	# background props and controls can consume this same outside click.
	if lab.dismiss_computer_view(button.position):
		return
	var hit: Dictionary = _pick(button.position)
	var clicked_id: String = "" if hit.is_empty() else str((hit["collider"] as Node).get_meta("prop_control", ""))
	if clicked_id.begins_with("keyboard.") and lab.camera.focused_item.is_empty():
		focus_item(controls[clicked_id]["holder"] as Node3D)
		get_viewport().set_input_as_handled()
		return
	# Controls win over the coarse focus boxes, including the computer's sloping case.
	if not lab.camera.focused_item.is_empty():
		var focused_hit: Dictionary = _pick(button.position, 8)
		var target: Node3D = null
		if not focused_hit.is_empty():
			target = (focused_hit["collider"] as Node).get_meta("focus_target") as Node3D
		var control_inside: bool = controls.has(clicked_id) and str((controls[clicked_id]["holder"] as Node3D).name) == lab.camera.focused_item
		var computer_inside: bool = lab.camera.focused_item == "Computer" and lab.computer_view_at(button.position).x >= 0
		if not control_inside and not computer_inside and (target == null or str(target.name) != lab.camera.focused_item):
			lab.select_view(4)
			get_viewport().set_input_as_handled()
			return
	if hit.is_empty():
		var focus_hit: Dictionary = _pick(button.position, 8)
		if not focus_hit.is_empty():
			if lab.camera.focused_item.is_empty():
				focus_item((focus_hit["collider"] as Node).get_meta("focus_target") as Node3D)
			get_viewport().set_input_as_handled()
		return
	active = clicked_id
	lab.end_screen_editing()
	if not bool(controls[active]["knob"]):
		var pivot: Node3D = controls[active]["pivot"]
		pivot.position = (controls[active]["rest"] as Vector3) + (controls[active]["axis"] as Vector3) * float(controls[active]["depth"])
		var sound: String = "keyboard_space" if active == "keyboard.space" else ("keyboard_key" if active.begins_with("keyboard.") else "button_press")
		audio.call("play_sound", sound, 1.0, 0.0, 0.025)
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if lab == null or _modal():
		cancel()
		return
	if active.is_empty():
		return
	if event is InputEventMouseMotion and bool(controls[active]["knob"]):
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		set_value(active, float(states[active]) + (motion.relative.x - motion.relative.y * 0.4) / 180.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			var hit: Dictionary = _pick(button.position)
			var released_on: String = "" if hit.is_empty() else str((hit["collider"] as Node).get_meta("prop_control", ""))
			if not bool(controls[active]["knob"]) and released_on == active:
				_activate(active)
			cancel()
			get_viewport().set_input_as_handled()

func set_value(id: String, value: float) -> void:
	if not controls.has(id):
		return
	var before: float = float(states[id])
	states[id] = clampf(value, 0, 1)
	if bool(controls[id]["knob"]):
		_apply_knob(id)
		if roundi(before * 24) != roundi(float(states[id]) * 24):
			audio.call("play_sound", "knob_detent", lerpf(0.85, 1.15, float(states[id])), 0.0, 0.035)
		elif not is_equal_approx(before, value) and (value < 0.0 or value > 1.0):
			audio.call("play_sound", "knob_limit", 1.0, 0.0, 0.18)
	if id == "lamp.power" and lamp_light != null:
		if lamp_light.has_method("set_powered"):
			lamp_light.call("set_powered", value > 0.5)
		else:
			lamp_light.visible = value > 0.5
		if not is_equal_approx(before, float(states[id])):
			audio.call("play_sound", "lamp_switch")
	if id.begins_with("radio."):
		if id == "radio.power" and not is_equal_approx(before, float(states[id])):
			audio.call("play_sound", "power_on" if float(states[id]) > 0.5 else "power_off")
		audio.call("set_radio", float(states["radio.power"]) > 0.5, states["radio.volume"], states["radio.tuning"])
	if id.begins_with("recorder."):
		if id != "recorder.level":
			if id == "recorder.play" and value <= 0.5 and tape_mode == "play":
				tape_mode = "pause"
			else:
				tape_mode = id.trim_prefix("recorder.") if value > 0.5 and id != "recorder.stop" else "stop"
			for mode: String in ["play", "rewind", "record"]:
				states["recorder." + mode] = 1.0 if tape_mode == mode else 0.0
			states["recorder.stop"] = 0.0
			audio.call("play_sound", "tape_record" if tape_mode == "record" else ("tape_stop" if tape_mode == "stop" else "button_release"))
			for mode: String in ["play", "rewind", "record", "stop"]:
				_refresh_button("recorder." + mode)
		audio.call("set_tape", tape_mode, states["recorder.level"])
		if reel_motion != null:
			reel_motion.call("set_mode", tape_mode)
	_refresh_button(id)
	control_changed.emit(id, float(states[id]))

func _apply_knob(id: String) -> void:
	(controls[id]["pivot"] as Node3D).rotation.z = lerpf(deg_to_rad(135), deg_to_rad(-135), float(states[id]))
	if id == "computer.knob":
		lab.desk.screen_brightness = lerpf(0.25, 1.25, float(states[id]))
		lab.desk.update_screen_tint()

func _activate(id: String) -> void:
	if id.begins_with("keyboard."):
		_send_key(id)
	elif id == "computer.power":
		lab.desk.interact("power")
	elif id == "computer.palette":
		var palette: int = (lab.desk.screen_palette + 1) % 3
		lab.desk.screen_palette = palette
		states[id] = float(palette) / 2.0
		lab.desk.update_screen_tint()
		audio.call("play_sound", "knob_detent", 1.25)
		control_changed.emit(id, float(states[id]))
	elif id == "computer.lock":
		lab.end_screen_editing()
		lab.desk.terminal_ui.lock_terminal()
		audio.call("play_sound", "power_off", 1.25, -3.0)
		control_changed.emit(id, 0.0)
	else:
		set_value(id, 1.0 - float(states[id]))

func _send_key(id: String) -> void:
	if not lab.desk.powered or lab.desk.terminal_ui.booting:
		return
	lab.editing_screen = true
	lab.desk.terminal_ui.begin_editing()
	var press: InputEventKey = InputEventKey.new()
	press.keycode = int(controls[id]["keycode"]) as Key
	press.physical_keycode = press.keycode
	press.unicode = int(controls[id]["unicode"])
	press.pressed = true
	lab.desk.terminal_view.push_input(press, true)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	lab.desk.terminal_view.push_input(release, true)

func _physical_key_changed(code: int, pressed: bool) -> void:
	if not key_bindings.has(code) or _modal():
		return
	var id: String = key_bindings[code]
	var pivot: Node3D = controls[id]["pivot"]
	if key_motions.has(id) and (key_motions[id] as Tween).is_valid():
		(key_motions[id] as Tween).kill()
	var motion: Tween = create_tween()
	key_motions[id] = motion
	motion.tween_property(pivot, "position", (controls[id]["rest"] as Vector3) + Vector3(0, -0.035 if pressed else 0.0, 0), 0.045)
	if pressed:
		audio.call("play_sound", "keyboard_space" if id == "keyboard.space" else "keyboard_key", 1.0, 0.0, 0.02)

func _refresh_button(id: String) -> void:
	if not controls.has(id) or bool(controls[id]["knob"]):
		return
	var control: Dictionary = controls[id]
	var latched: bool = id in ["recorder.play", "recorder.rewind", "recorder.record"] and float(states[id]) > 0.5
	(control["pivot"] as Node3D).position = (control["rest"] as Vector3) + ((control["axis"] as Vector3) * float(control["depth"]) * 0.7 if latched else Vector3.ZERO)
	if control.has("material"):
		var mat: StandardMaterial3D = control["material"]
		mat.albedo_color = Color("e684a0") if id == "recorder.record" and latched else (Color("ffe6ac") if latched or float(states[id]) > 0.5 else Color("e1bd92"))

func cancel() -> void:
	if controls.has(active):
		_refresh_button(active)
	active = ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel()
