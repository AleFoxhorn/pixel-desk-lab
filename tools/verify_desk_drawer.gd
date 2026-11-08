extends SceneTree
## Exercise actual viewport input, interrupted animations and camera ownership.
var lab: Control
var drawer: Node3D
var changes: int = 0

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func _changed(_open: bool) -> void:
	changes += 1

func handle_pixel() -> Vector2:
	var camera: Camera3D = lab.get("camera") as Camera3D
	var handle: Node3D = drawer.get_node("Slide/CreamHandle") as Node3D
	var viewport: SubViewport = lab.get("scene_view") as SubViewport
	var image: TextureRect = lab.get("image") as TextureRect
	var target_uv: Vector2 = camera.unproject_position(handle.global_position) / Vector2(viewport.size)
	var uv: Vector2 = target_uv
	# Invert the same print distortion as the live picker, including at low resolution.
	for iteration: int in range(5):
		var screen_pixel: Vector2 = image.global_position + uv * image.size
		uv += target_uv - (lab.call("image_uv", screen_pixel) as Vector2)
	return image.global_position + uv * image.size

func click_handle() -> void:
	var pixel: Vector2 = handle_pixel()
	var hit: Dictionary = lab.call("pick", pixel)
	check(hit.get("collider") == drawer.get_node("Slide/HandleHit"), "Rendered handle must match the physics picker")
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = pixel
	press.global_position = pixel
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)

func shot(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://verification/" + file_name + ".png")) == OK, "Screenshot must save")

func verify() -> void:
	root.size = Vector2i(1280, 720)
	lab = (load("res://scenes/lab.tscn") as PackedScene).instantiate() as Control
	root.add_child(lab)
	current_scene = lab
	await create_timer(0.3).timeout
	drawer = lab.get_node("SceneViewport/DeskWorld/CabinEnvironment/DeskDrawer") as Node3D
	drawer.connect("open_changed", _changed)
	var slide: Node3D = drawer.get_node("Slide") as Node3D
	var file: Node3D = drawer.get_node("Slide/Files/BlueFile") as Node3D
	var camera: Camera3D = lab.get("camera") as Camera3D
	var file_rest: Vector3 = file.global_position
	var focus_rest: Vector3 = camera.get("focus_point")
	var distance_rest: float = float(camera.get("orbit_distance"))
	check(not bool(drawer.get("is_open")) and slide.position.is_equal_approx(Vector3.ZERO), "Drawer must start closed")
	check(handle_pixel().y < float(root.size.y) - 100.0, "Closed handle must clear the bottom toolbar")
	await shot("drawer_closed")
	click_handle()
	check(bool(drawer.get("is_open")), "Actual pointer input must open the drawer")
	await create_timer(1.05).timeout
	check(is_equal_approx(slide.position.z, 1.58), "Drawer must reach the open stop")
	check(file.global_position.is_equal_approx(file_rest + Vector3(0, 0, 1.58)), "Files must travel with the tray")
	check((camera.get("focus_point") as Vector3).distance_to(drawer.global_position + Vector3(0, 0.14, 0.72)) < 0.001, "Opening must frame the files")
	await shot("drawer_open")
	click_handle()
	check(not bool(drawer.get("is_open")), "Actual pointer input must close the drawer")
	await create_timer(1.0).timeout
	check(slide.position.is_equal_approx(Vector3.ZERO), "Drawer must close without drift")
	check((camera.get("focus_point") as Vector3).is_equal_approx(focus_rest) and is_equal_approx(float(camera.get("orbit_distance")), distance_rest), "Closing must restore the original framing")
	# Reverse while still moving; the final state must stay deterministic.
	drawer.call("set_open", true)
	await create_timer(0.18).timeout
	drawer.call("set_open", false)
	await create_timer(0.11).timeout
	drawer.call("set_open", true)
	await create_timer(0.12).timeout
	drawer.call("set_open", false)
	await create_timer(1.0).timeout
	check(slide.position.is_equal_approx(Vector3.ZERO) and not bool(drawer.get("is_open")), "Rapid toggles must end fully closed")
	check((camera.get("focus_point") as Vector3).is_equal_approx(focus_rest), "Interrupted camera returns must preserve the original view")
	# A manually chosen view wins over the automatic close-up.
	drawer.call("set_open", true)
	await create_timer(0.9).timeout
	lab.call("select_view", 1, true)
	var side_focus: Vector3 = camera.get("focus_point")
	drawer.call("set_open", false)
	await create_timer(0.9).timeout
	check(int(camera.get("active_view")) == 1 and (camera.get("focus_point") as Vector3).is_equal_approx(side_focus), "Closing must respect a manually selected view")
	# Physics and render coordinates must also agree at the existing pixel preset.
	lab.call("select_view", 4, true)
	var resolution: OptionButton = lab.get("resolution") as OptionButton
	resolution.select(0)
	lab.call("_update_resolution")
	await create_timer(0.15).timeout
	click_handle()
	check(bool(drawer.get("is_open")), "Handle must remain clickable at 640x360")
	await create_timer(0.9).timeout
	await shot("drawer_open_pixel")
	click_handle()
	await create_timer(0.9).timeout
	check(not bool(drawer.get("is_open")) and changes == 10, "Every state change must emit exactly once")
	print("DRAWER_CHECK_OK: pointer open/close, file parenting, camera return, rapid reversal, manual views, 640x360 picking; transitions=", changes)
	lab.queue_free()
	await process_frame
	quit()
