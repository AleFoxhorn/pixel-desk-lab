extends SceneTree

var lab: Control
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func key(code: int, character: int = 0, shift: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code as Key
	event.physical_keycode = code as Key
	event.unicode = character
	event.shift_pressed = shift
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	root.push_input(event, true)

func mouse(at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	lab = load("res://scenes/lab.tscn").instantiate() as Control
	root.add_child(lab)
	await process_frame
	await process_frame
	lab.set_print_preset(0)
	lab.select_view(0, true)
	await process_frame
	check(lab.desk.terminal_view.size == Vector2i(320, 160), "Terminal uses native low-resolution pixels independently of scene resolution")
	var editor: TextEdit = lab.desk.terminal_ui.editor
	var camera: Camera3D = lab.camera
	check(camera.global_position.x == lab.desk.screen.global_position.x, "Front must align with screen X")
	check(camera.global_position.y == lab.desk.screen.global_position.y, "Front must align with screen Y")
	var point: Vector3 = lab.desk.screen.to_global(Vector3(0, 0, 0))
	var viewport_point: Vector2 = camera.unproject_position(point)
	var click: Vector2 = lab.image.global_position + viewport_point / Vector2(lab.scene_view.size) * lab.image.size
	check(lab.screen_coordinates(click).distance_to(Vector2(lab.desk.ScreenSurface.TEXTURE_SIZE) * 0.5) < 1.0, "Ray to screen UV")
	mouse(click, true)
	mouse(click, false)
	await process_frame
	check(lab.editing_screen, "Click screen enters editing")
	var terminal: Control = lab.desk.terminal_ui
	check(not terminal.unlocked and not editor.visible, "Screen starts locked with protected content hidden")
	check(terminal.password_input.has_focus(), "Click screen focuses password")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://verification/screen_locked.png")
	for character: String in "HELLOWORLD":
		key(character.to_upper().unicode_at(0), character.unicode_at(0))
	var unlock_uv: Vector2 = terminal.unlock_button.get_global_rect().get_center() / Vector2(lab.desk.ScreenSurface.TEXTURE_SIZE)
	var unlock_world: Vector3 = lab.desk.screen.to_global(Vector3((unlock_uv.x - 0.5) * 2.5, (0.5 - unlock_uv.y) * 1.25, 0))
	var unlock_pixel: Vector2 = camera.unproject_position(unlock_world)
	var unlock_click: Vector2 = lab.image.global_position + unlock_pixel / Vector2(lab.scene_view.size) * lab.image.size
	mouse(unlock_click, true)
	mouse(unlock_click, false)
	await process_frame
	check(not terminal.unlocked and terminal.access_status.text == "ACCESS DENIED", "Click unlock rejects password without space")
	check(not terminal.boot_audio.success.playing and terminal.boot_audio.pending_start < 0, "Wrong password does not trigger success audio")
	for character: String in "hello world":
		key(character.to_upper().unicode_at(0), character.unicode_at(0))
	key(KEY_ENTER)
	await process_frame
	check(not terminal.unlocked, "Password comparison is case sensitive")
	check(terminal.access_status.text == "ACCESS DENIED", "Wrong password shows failure feedback")
	check(terminal.password_input.text.is_empty(), "Wrong password is cleared for retry")
	check(editor.text.is_empty(), "Wrong password cannot edit protected content")
	for character: String in "HELLO WORLD":
		key(character.to_upper().unicode_at(0), character.unicode_at(0))
	key(KEY_ENTER)
	check(terminal.boot_audio.success.playing, "Correct password immediately plays confirmation")
	await process_frame
	check(terminal.booting and not terminal.unlocked and not editor.visible, "Correct password starts boot before exposing editor")
	check(terminal.boot_audio.pending_start > 0, "Startup follows confirmation without overlap")
	key(KEY_A, 97)
	key(KEY_ENTER)
	await process_frame
	check(editor.text.is_empty(), "Boot blocks typing")
	await create_timer(0.7).timeout
	check(terminal.boot_emblem.visible and not terminal.content_panel.visible, "Boot icon occupies display without terminal text")
	check(terminal.boot_audio.startup.playing, "Retro startup accompanies logo")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://verification/screen_boot_emblem.png")
	await create_timer(1.8).timeout
	check(not terminal.boot_emblem.visible and terminal.content_panel.visible, "Logo transitions into diagnostics")
	check(terminal.boot_label.visible_characters > 0 and terminal.boot_label.visible, "Boot reveals diagnostic text over time")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://verification/screen_boot.png")
	lab.select_view(1, true)
	await create_timer(2.5).timeout
	check(not editor.has_focus(), "Boot must not steal focus after leaving screen")
	check(not terminal.boot_audio.startup.playing, "Startup sound ends without looping")
	lab.select_view(0, true)
	mouse(click, true)
	mouse(click, false)
	await process_frame
	check(terminal.unlocked and editor.visible and not terminal.lock_area.visible and not terminal.booting, "Boot finishes into unlocked terminal")
	check(terminal.password_input.text.is_empty(), "Accepted password is cleared")
	check(editor.has_focus(), "Native TextEdit must receive focus")
	for digit: int in [49, 50, 51, 52]:
		key(digit, digit)
	await process_frame
	check(editor.text == "1234", "Typing 1–4 must enter text without changing view: " + editor.text)
	check(lab.camera.active_view == 0, "Digits must not change view")
	key(KEY_ENTER)
	key(KEY_A, 65, true)
	key(KEY_B, 98)
	key(KEY_BACKSPACE)
	await process_frame
	check(editor.text == "1234\nA", "Enter, shift character, backspace")
	key(KEY_LEFT)
	key(KEY_DELETE)
	await process_frame
	check(editor.text == "1234\n", "Cursor navigation and forward delete")
	key(KEY_NONE, 0x4e2d)
	key(KEY_NONE, 0x6587)
	await process_frame
	check(editor.text == "1234\n中文", "Unicode committed text")
	editor.select_all()
	key(KEY_Z, 122)
	await process_frame
	check(editor.text == "z", "Selection replacement")
	var saved_text: String = editor.text
	var side_button: Button = lab.view_buttons[1]
	mouse(side_button.get_global_rect().get_center(), true)
	mouse(side_button.get_global_rect().get_center(), false)
	await process_frame
	check(lab.camera.active_view == 1, "Click side button changes camera")
	check(not lab.editing_screen and not editor.has_focus(), "Leaving view releases input focus")
	key(KEY_A, 97)
	await process_frame
	check(editor.text == saved_text, "Text stays unchanged outside editing")
	lab.select_view(0, true)
	mouse(click, true)
	mouse(click, false)
	await process_frame
	check(editor.text == saved_text, "Text survives view changes")
	check(terminal.unlocked, "View changes preserve unlocked state")
	lab.desk._toggle_power()
	await process_frame
	key(KEY_A, 97)
	await process_frame
	check(editor.text == saved_text, "Power off blocks typing")
	terminal.boot_audio.play_unlock()
	lab.desk._toggle_power()
	lab.desk._toggle_power()
	check(not terminal.boot_audio.success.playing and terminal.boot_audio.pending_start < 0, "Power off stops audio and cancels queued startup")
	lab.desk._toggle_power()
	lab.end_screen_editing()
	editor.text = "ONLINE_\nREADY FOR INPUT\n现实键盘 → 屏幕输入"
	lab.set_print_preset(1)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://verification/screen_interaction.png")
		var terminal_pixels: Image = lab.desk.terminal_view.get_texture().get_image()
		check(terminal_pixels.get_size() == Vector2i(320, 160), "Actual rendered screen texture must be low-resolution")
		terminal_pixels.resize(1280, 640, Image.INTERPOLATE_NEAREST)
		terminal_pixels.save_png("res://verification/screen_pixels_4x.png")
		lab.select_view(3, true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://verification/screen_pixels_close.png")
	print("SCREEN_VERIFY: ", "PASS" if failures.is_empty() else str(failures))
	lab.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
