extends Node
## Lift the actual drawer object into the existing camera, preserving the shared print pass.
signal inspecting_changed(active: bool)
var lab: Control
var active: bool = false
var returning: bool = false
var dragging: bool = false
var bird: Node3D
var drawer: Node3D
var rest_parent: Node3D
var rest_transform: Transform3D
var pivot: Node3D
var inspection_light: OmniLight3D
var motion: Tween
var layer: CanvasLayer
var close_button: Button

func setup(host: Control) -> void:
	lab = host
	layer = CanvasLayer.new()
	layer.name = "InspectionControls"
	layer.layer = 12
	lab.add_child(layer)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.position = Vector2(24, 24)
	bar.add_theme_constant_override("separation", 16)
	bar.theme = lab.theme
	layer.add_child(bar)
	var hint: Label = Label.new()
	hint.text = "拖动旋转"
	bar.add_child(hint)
	close_button = Button.new()
	close_button.text = "放回"
	close_button.tooltip_text = "放回抽屉 · Esc"
	close_button.pressed.connect(close)
	bar.add_child(close_button)
	layer.hide()

func open() -> void:
	if active:
		return
	drawer = lab.desk.get_node("CabinEnvironment/DeskDrawer") as Node3D
	if not drawer.is_open:
		return
	bird = drawer.get_node("Slide/OrigamiBird") as Node3D
	rest_parent = bird.get_parent() as Node3D
	rest_transform = bird.transform
	var bounds: AABB = AABB()
	var first: bool = true
	for node: Node in bird.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var box: AABB = (bird.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first:
		return
	active = true
	returning = false
	dragging = false
	(bird.get_node("OrigamiHit") as StaticBody3D).collision_layer = 0
	pivot = Node3D.new()
	pivot.name = "HeldOrigami"
	lab.camera.add_child(pivot)
	pivot.position = Vector3(0, 0, -2.2)
	inspection_light = OmniLight3D.new()
	inspection_light.name = "OrigamiInspectionLight"
	lab.camera.add_child(inspection_light)
	inspection_light.position = Vector3(-0.8, 0.7, -1.4)
	inspection_light.light_color = Color("fff0d0")
	inspection_light.light_energy = 1.2
	inspection_light.omni_range = 2.8
	bird.reparent(pivot, true)
	var factor: float = 1.15 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(-32.0)).scaled(Vector3.ONE * factor)
	var target: Transform3D = Transform3D(basis, -(basis * bounds.get_center()))
	motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(bird, "transform", target, 0.35)
	layer.show()
	inspecting_changed.emit(true)
	lab.control_audio.play_sound("paper")

func close() -> void:
	if not active or returning:
		return
	returning = true
	dragging = false
	if motion != null and motion.is_valid():
		motion.kill()
	bird.reparent(rest_parent, true)
	motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(bird, "transform", rest_transform, 0.28)
	motion.tween_callback(_returned)
	lab.control_audio.play_sound("paper", 0.87)

func _returned() -> void:
	bird.transform = rest_transform
	(bird.get_node("OrigamiHit") as StaticBody3D).collision_layer = 1 if drawer.is_open else 0
	inspection_light.queue_free()
	inspection_light = null
	pivot.queue_free()
	pivot = null
	active = false
	returning = false
	layer.hide()
	inspecting_changed.emit(false)

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if close_button.get_global_rect().has_point(button.position):
			return
		if button.button_index == MOUSE_BUTTON_LEFT:
			dragging = button.pressed and not returning
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging and not returning:
		var move: InputEventMouseMotion = event as InputEventMouseMotion
		pivot.rotation.y += move.relative.x * 0.009
		pivot.rotation.x = clampf(pivot.rotation.x + move.relative.y * 0.009, -1.3, 1.3)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
