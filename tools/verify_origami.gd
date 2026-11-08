extends SceneTree
var lab: Control
var drawer: Node3D
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func click(at: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = at
	press.global_position = at
	press.pressed = true
	root.push_input(press, true)
	press = press.duplicate() as InputEventMouseButton
	press.pressed = false
	root.push_input(press, true)
func shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://verification/" + name + ".png")
func run() -> void:
	lab = load("res://scenes/lab.tscn").instantiate() as Control
	root.add_child(lab)
	await process_frame
	await physics_frame
	drawer = lab.desk.get_node("CabinEnvironment/DeskDrawer") as Node3D
	var bird: Node3D = drawer.get_node("Slide/OrigamiBird") as Node3D
	var rest: Transform3D = bird.transform
	check(not (lab.desk.get_node("GeneratedProps/OrigamiBird") as Node3D).visible, "Desktop copy must be hidden")
	check(lab.print_option.selected == 1 and is_equal_approx(lab.print_strength, 0.45), "Default is light print")
	check((bird.get_node("OrigamiHit") as StaticBody3D).collision_layer == 0, "Closed drawer origami cannot be picked")
	drawer.set_open(true)
	await create_timer(1.0).timeout
	await physics_frame
	check((bird.get_node("OrigamiHit") as StaticBody3D).collision_layer == 1, "Open drawer enables origami")
	await shot("origami_in_drawer")
	var pixel: Vector2 = lab.camera.unproject_position(bird.global_position)
	var target_uv: Vector2 = pixel / Vector2(lab.scene_view.size)
	var uv: Vector2 = target_uv
	for index: int in range(6):
		uv += target_uv - lab.image_uv(lab.image.global_position + uv * lab.image.size)
	var at: Vector2 = lab.image.global_position + uv * lab.image.size
	var hit: Dictionary = lab.pick(at)
	check(hit.get("collider") == bird.get_node("OrigamiHit"), "Actual pointer must hit origami in the drawer")
	click(at)
	await process_frame
	check(lab.origami_inspector.active, "Click lifts origami into inspection")
	await create_timer(0.4).timeout
	check(bird.get_parent() == lab.origami_inspector.pivot, "Held bird is physically lifted from drawer")
	check(is_equal_approx(lab.print_strength, 1.65), "Inspection triggers heavy print")
	await shot("origami_inspect_heavy")
	var pivot: Node3D = lab.origami_inspector.pivot
	var rotation_before: Vector3 = pivot.rotation
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(600, 360)
	press.pressed = true
	root.push_input(press, true)
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = Vector2(680, 390)
	move.relative = Vector2(80, 30)
	root.push_input(move, true)
	press.pressed = false
	root.push_input(press, true)
	check(not pivot.rotation.is_equal_approx(rotation_before), "Dragging rotates held paper")
	await create_timer(0.7).timeout
	check(is_equal_approx(lab.print_strength, 1.65), "Heavy print persists while paper is held")
	await create_timer(0.4).timeout
	check(is_equal_approx(lab.print_strength, 1.65) and lab.inspection_print_active, "Heavy print does not expire after one second")
	await shot("origami_inspect_rotated")
	click(lab.origami_inspector.close_button.get_global_rect().get_center())
	await create_timer(0.35).timeout
	check(not lab.origami_inspector.active, "Put-back button ends inspection")
	check(is_equal_approx(lab.print_strength, 0.45) and lab.print_option.selected == 1, "Putting paper back restores light print")
	check(bird.get_parent() == drawer.get_node("Slide") and bird.transform.is_equal_approx(rest), "Bird returns to its original drawer transform")
	lab.open_origami()
	await create_timer(0.1).timeout
	drawer.set_open(false)
	await create_timer(0.8).timeout
	check(not lab.origami_inspector.active and bird.get_parent() == drawer.get_node("Slide"), "Closing the drawer returns held origami safely")
	check((bird.get_node("OrigamiHit") as StaticBody3D).collision_layer == 0, "Closed drawer disables returned origami")
	print("ORIGAMI_VERIFY: ", "PASS" if failures.is_empty() else str(failures))
	lab.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
