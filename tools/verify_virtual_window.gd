extends SceneTree
## Actual viewport clicks exercise the curved window and its brief green reveal.
var lab: Control
var window: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func project(point: Vector3) -> Vector2:
	var camera: Camera3D = lab.get("camera") as Camera3D
	var viewport: SubViewport = lab.get("scene_view") as SubViewport
	var image: TextureRect = lab.get("image") as TextureRect
	var target: Vector2 = camera.unproject_position(point) / Vector2(viewport.size)
	var uv: Vector2 = target
	for iteration: int in range(5):
		uv += target - (lab.call("image_uv", image.global_position + uv * image.size) as Vector2)
	return image.global_position + uv * image.size

func window_pixel() -> Vector2:
	var guess: Vector2 = project(Vector3(7.0, 4.5, -2.56))
	if bool(window.call("pick_window", guess)):
		return guess
	for radius: int in [2, 4, 6, 8, 12]:
		for offset: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius), Vector2(radius, radius), Vector2(-radius, radius), Vector2(radius, -radius), Vector2(-radius, -radius)]:
			if bool(window.call("pick_window", guess + offset)):
				return guess + offset
	check(false, "Visible glass must be pickable through the 640x360 print warp")
	return guess

func outside_pixel() -> Vector2:
	for at: Vector2 in [Vector2(8, 100), Vector2(8, 610), Vector2(1272, 100), Vector2(1272, 610), Vector2(8, 8)]:
		if not bool(window.call("pick_window", at)):
			return at
	check(false, "Focused window must leave an outside point for click-away dismissal")
	return Vector2(8, 8)

func click(at: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = at
	press.global_position = at
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)

func escape() -> void:
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_ESCAPE
	press.physical_keycode = KEY_ESCAPE
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)

func shot(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://verification/" + file_name + ".png")) == OK, "Window screenshot must save")

func check_closed(message: String) -> void:
	var camera: Node = lab.get("camera") as Node
	var effect: Node = window.get("effect") as Node
	var material: ShaderMaterial = effect.get("material") as ShaderMaterial
	check(not bool(window.get("active")) and str(camera.get("focused_item")).is_empty(), message)
	check(not bool(effect.get("effect_active")) and is_zero_approx(float(material.get_shader_parameter("reveal_amount"))), "Leaving the window must clear its green reveal")

func run() -> void:
	root.size = Vector2i(1280, 720)
	lab = (load("res://scenes/lab.tscn") as PackedScene).instantiate() as Control
	root.add_child(lab)
	current_scene = lab
	await create_timer(0.8).timeout
	window = lab.get("virtual_window") as Node
	check(window != null, "Scene must bind the virtual window controller")
	if window == null:
		lab.queue_free()
		await process_frame
		quit(1)
		return
	var camera: Node = lab.get("camera") as Node
	var effect: Node = window.get("effect") as Node
	var material: ShaderMaterial = effect.get("material") as ShaderMaterial
	var viewport: SubViewport = lab.get("scene_view") as SubViewport
	check(viewport.size == Vector2i(640, 360) and (lab.get("print_pass") as Control).visible, "Window picking must use the live pixel and print preset")
	check((window.get("body") as StaticBody3D).collision_layer == 256, "Window must use its dedicated collision layer")
	check(not bool(window.call("pick_window", project(Vector3(9.5, 6.3, -2.56)))), "Outside the curved upper-right contour must not hit the glass")
	click(window_pixel())
	await process_frame
	check(bool(window.get("active")) and str(camera.get("focused_item")) == "Window", "Clicking visible glass must enter the window close-up")
	await create_timer(0.95).timeout
	await physics_frame
	await shot("window_close")
	# Re-trigger after the camera settles so the short blink is visible in the capture.
	effect.call("trigger")
	await create_timer(0.06).timeout
	check(bool(effect.get("effect_active")) and float(material.get_shader_parameter("reveal_amount")) > 0.0, "Green reveal must be active briefly after triggering")
	await shot("window_reveal")
	await create_timer(0.75).timeout
	check(not bool(effect.get("effect_active")) and is_zero_approx(float(material.get_shader_parameter("reveal_amount"))), "Green reveal must finish and restore the glass within 0.8 seconds")
	var original_motion: Tween = camera.get("motion") as Tween
	click(window_pixel())
	await process_frame
	check(bool(window.get("active")) and (camera.get("motion") as Tween) == original_motion, "Repeated window clicks must not restart the camera tween")
	escape()
	await process_frame
	check_closed("Esc must leave the window close-up")
	check(int(camera.get("active_view")) == 4, "Esc must return to the environment view")
	await create_timer(1.1).timeout
	click(window_pixel())
	await create_timer(0.95).timeout
	click(outside_pixel())
	await process_frame
	check_closed("Outside click must leave the window without activating another target")
	check(int(camera.get("active_view")) == 4, "Outside click must return to the environment view")
	await create_timer(1.1).timeout
	# The reader owns input while open, even where the window is visible behind it.
	var at: Vector2 = window_pixel()
	lab.call("open_desk_file", 0)
	await process_frame
	click(at)
	await process_frame
	check(not bool(window.get("active")) and str(camera.get("focused_item")).is_empty(), "Reading modal must prevent background window activation")
	(lab.get("file_reader") as Node).call("close")
	click(window_pixel())
	await create_timer(0.95).timeout
	var buttons: Array = lab.get("view_buttons")
	var environment: Button = buttons[4] as Button
	click(environment.get_global_rect().get_center())
	await process_frame
	check_closed("A scene view button must also leave the window close-up")
	check(int(camera.get("active_view")) == 4, "View button must retain its requested camera preset")
	if failures.is_empty():
		print("VIRTUAL_WINDOW_VERIFY: PASS (pixel-warped glass hit, contour miss, close-up, brief reveal reset, repeat click, Esc, outside dismissal, modal isolation, view-button exit)")
		if OS.get_cmdline_user_args().has("--keep-open"):
			window.call("open")
			print("VIRTUAL_WINDOW_PLAYTEST_READY")
			return
	else:
		print("VIRTUAL_WINDOW_VERIFY: FAIL ", JSON.stringify(failures))
	lab.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
