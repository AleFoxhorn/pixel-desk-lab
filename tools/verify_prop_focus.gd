extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab: Control = load("res://scenes/lab.tscn").instantiate() as Control
	root.add_child(lab)
	await create_timer(0.7).timeout
	lab.set_print_preset(0)
	var controller: Node = lab.prop_input
	var props: Node = lab.desk.find_child("GeneratedProps", true, false)
	for item: String in ["Keyboard", "Lamp", "Radio", "Recorder"]:
		lab.select_view(4, true)
		await physics_frame
		var holder: Node3D = props.get_node(item) as Node3D
		var bounds: AABB = holder.global_transform * (controller.focus_targets[holder.get_instance_id()]["bounds"] as AABB)
		var aim: Vector3 = bounds.get_center()
		if item == "Lamp":
			aim.y = bounds.position.y + bounds.size.y * 0.78
		var pixel: Vector2 = lab.camera.unproject_position(aim)
		var at: Vector2 = lab.image.global_position + pixel / Vector2(lab.scene_view.size) * lab.image.size
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.position = at
		click.global_position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		root.push_input(click, true)
		await process_frame
		assert(lab.camera.focused_item == item, "Click must focus " + item)
		click.pressed = false
		root.push_input(click, true)
		await create_timer(1.0).timeout
		assert(lab.camera.focus_point.distance_to(bounds.get_center()) < 0.001)
		for corner: int in range(8):
			var point: Vector3 = bounds.get_endpoint(corner)
			var projected: Vector2 = lab.camera.unproject_position(point)
			assert(Rect2(Vector2.ZERO, Vector2(lab.scene_view.size)).has_point(projected), "Focus must frame entire " + item)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://verification/focus_" + item.to_lower() + ".png")
		var escape: InputEventKey = InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape, true)
		assert(lab.camera.active_view == 4)
		assert(lab.camera.focused_item.is_empty())
	print("PROP_FOCUS_VERIFY: PASS (four real clicks, tween targets, eight corners each, Escape return)")
	lab.queue_free()
	await process_frame
	quit()
