extends Node
## The cabin's star field is an in-world display, with a brief maintenance-grid reveal.
const Reveal: Script = preload("res://scripts/window_reveal.gd")
const COLLISION_LAYER: int = 256
var lab: Control
var glass: MeshInstance3D
var body: StaticBody3D
var effect: Node3D
var active: bool = false
var reveal_job: Tween = null

func setup(host: Control, cabin: Node3D) -> void:
	lab = host
	process_priority = 2
	glass = cabin.get_node("DeepSpace") as MeshInstance3D
	body = StaticBody3D.new()
	body.name = "WindowHit"
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0
	var shape: ConcavePolygonShape3D = glass.mesh.create_trimesh_shape()
	shape.backface_collision = true
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "GlassOutline"
	collision.shape = shape
	body.add_child(collision)
	glass.add_child(body)
	effect = Reveal.new()
	effect.name = "WindowReveal"
	cabin.add_child(effect)
	effect.call("setup", cabin)
	# Camera preset buttons change focus in their signal callback. Clear the reveal
	# in that same callback instead of waiting for this node's next process tick.
	for button: Button in lab.view_buttons:
		if not button.pressed.is_connected(_clear):
			button.pressed.connect(_clear)

func pick_window(at: Vector2) -> bool:
	if lab == null or glass == null or lab.camera.global_position.z <= -2.56:
		return false
	# Precise computer and foreground object hits take precedence over the display behind.
	var mask: int = COLLISION_LAYER | lab.desk.COMPUTER_COLLISION_LAYER | lab.desk.SCREEN_COLLISION_LAYER | 4 | 8 | 1
	var hit: Dictionary = lab.pick(at, mask)
	return not hit.is_empty() and hit.get("collider") == body

func open() -> void:
	if lab.file_reader != null and lab.file_reader.visible:
		return
	lab.prop_input.cancel()
	lab.end_screen_editing()
	active = true
	lab.camera.focus_bounds(glass.global_transform * glass.get_aabb(), "Window", 0.0, 0.0)
	for button: Button in lab.view_buttons:
		button.set_pressed_no_signal(false)
	_schedule_reveal(0.56)

func _schedule_reveal(delay: float) -> void:
	if reveal_job != null and reveal_job.is_valid():
		reveal_job.kill()
	reveal_job = create_tween()
	reveal_job.tween_interval(delay)
	reveal_job.tween_callback(_reveal)

func _reveal() -> void:
	if active and lab.camera.focused_item == "Window":
		effect.call("trigger")

func _clear() -> void:
	active = false
	if reveal_job != null and reveal_job.is_valid():
		reveal_job.kill()
	if effect != null:
		effect.call("stop")

func close() -> void:
	_clear()
	lab.select_view(4)

func _unhandled_input(event: InputEvent) -> void:
	if lab == null or (lab.file_reader != null and lab.file_reader.visible):
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_ESCAPE and active:
		close()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	var on_glass: bool = pick_window(button.position)
	if on_glass:
		if active:
			_schedule_reveal(0.02)
		else:
			open()
	elif active:
		close()
	else:
		return
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if lab == null:
		return
	if active and lab.camera.focused_item != "Window":
		_clear()
	if lab.file_reader != null and lab.file_reader.visible:
		return
	var on_glass: bool = pick_window(lab.get_global_mouse_position())
	if active or on_glass:
		lab.status.text = "窗外 · 点击空白返回" if active else "窗外 · 点击查看"
		lab.image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on_glass else Control.CURSOR_ARROW
