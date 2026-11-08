extends SceneTree
var lab: Control
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func click_world(point: Vector3, expected: int) -> void:
	await physics_frame
	var pixel: Vector2 = lab.camera.unproject_position(point)
	var at: Vector2 = lab.image.global_position + pixel / Vector2(lab.scene_view.size) * lab.image.size
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = at
	click.global_position = at
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	if lab.camera.active_view != expected:
		failures += 1
		push_error("Surface expected %d got %d focused %s at %s" % [expected, lab.camera.active_view, lab.camera.focused_item, str(point)])
	click.pressed = false
	root.push_input(click, true)
	await create_timer(1.15).timeout
func run() -> void:
	lab = load("res://scenes/lab.tscn").instantiate() as Control
	root.add_child(lab)
	await create_timer(0.7).timeout
	lab.set_print_preset(0)
	lab.select_view(4, true)
	await click_world(Vector3(-1.25, 2.8, 0.7), 1)
	assert(lab.camera.orbit_yaw < 0)
	await click_world(Vector3(-1.375, 2.6, -0.65), 2)
	await click_world(Vector3(1.25, 2.7, -0.9), 1)
	assert(sin(lab.camera.orbit_yaw) > 0)
	await click_world(Vector3(0.5, 2.88, 0.7), 0)
	lab.select_view(4, true)
	await click_world(lab.desk.screen.global_position, 3)
	assert(lab.editing_screen)
	var outside: InputEventMouseButton = InputEventMouseButton.new()
	outside.position = Vector2(30,100)
	outside.global_position = outside.position
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	root.push_input(outside, true)
	assert(lab.camera.active_view == 4)
	print("CAMERA_SURFACES_VERIFY: ", "PASS" if failures == 0 else "FAIL")
	lab.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
