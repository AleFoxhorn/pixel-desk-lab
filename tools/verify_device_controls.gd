extends SceneTree
## Exercise the real model controls through viewport input, including warped pixel picking.
var lab: Control
var controller: Node
var sound: Node
var heard: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _played(sound_id: String) -> void:
	heard.append(sound_id)

func _controls() -> Dictionary:
	return controller.get("controls") as Dictionary

func _states() -> Dictionary:
	return controller.get("states") as Dictionary

func _state(id: String) -> float:
	return float(_states().get(id, -1.0))

func _loop(id: String) -> AudioStreamPlayer:
	return (sound.get("loops") as Dictionary).get(id) as AudioStreamPlayer

func _audible(id: String) -> bool:
	var player: AudioStreamPlayer = _loop(id)
	return player != null and player.playing and not player.stream_paused and player.volume_db > -60.0

func _hit_id(at: Vector2) -> String:
	var hit: Dictionary = controller.call("_pick", at)
	if hit.is_empty():
		return ""
	return str((hit["collider"] as Node).get_meta("prop_control", ""))

func control_pixel(id: String) -> Vector2:
	var data: Dictionary = _controls()[id]
	var body: Node3D = data["body"] as Node3D
	var camera: Camera3D = lab.get("camera") as Camera3D
	var viewport: SubViewport = lab.get("scene_view") as SubViewport
	var image: TextureRect = lab.get("image") as TextureRect
	var target_uv: Vector2 = camera.unproject_position(body.global_position) / Vector2(viewport.size)
	var uv: Vector2 = target_uv
	# The print pass samples pixel centres; an exact inverse can straddle a source pixel.
	for iteration: int in range(5):
		uv += target_uv - (lab.call("image_uv", image.global_position + uv * image.size) as Vector2)
	var guess: Vector2 = image.global_position + uv * image.size
	if _hit_id(guess) == id:
		return guess
	for radius: int in [2, 4, 6, 8, 10]:
		for offset: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius), Vector2(radius, radius), Vector2(-radius, radius), Vector2(radius, -radius), Vector2(-radius, -radius)]:
			if _hit_id(guess + offset) == id:
				return guess + offset
	expect(false, "Visible control must be ray-pickable at the sampled print pixels: " + id)
	return guess

func mouse(at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	root.push_input(event, true)

func motion(at: Vector2, relative: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)

func key(code: Key, unicode: int = 0) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	root.push_input(event, true)
	var release: InputEventKey = event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)

func tap(id: String) -> void:
	var at: Vector2 = control_pixel(id)
	expect(_hit_id(at) == id, "Press must begin over " + id)
	mouse(at, true)
	await process_frame
	mouse(control_pixel(id), false)
	await process_frame

func drag(id: String, delta: float, release_outside: bool = false) -> void:
	var at: Vector2 = control_pixel(id)
	mouse(at, true)
	await process_frame
	expect(str(controller.get("active")) == id, "Pointer press must capture " + id)
	motion(at + Vector2(clampf(delta, -160, 160), 0), Vector2(delta, 0))
	await process_frame
	mouse(Vector2(8, 90) if release_outside else control_pixel(id), false)
	await process_frame
	expect(str(controller.get("active")).is_empty(), "Release must clear capture for " + id)

func focus(item: String) -> void:
	var desk: Node3D = lab.get("desk") as Node3D
	var holder: Node3D = desk.get_node("Computer/Keyboard") as Node3D if item == "Keyboard" else desk.get_node("GeneratedProps/" + item) as Node3D
	controller.call("focus_item", holder)
	await create_timer(0.95).timeout
	await physics_frame
	expect(str((lab.get("camera") as Node).get("focused_item")) == item, "Focus must frame " + item)

func shot(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://verification/" + file_name + ".png")
	expect(root.get_texture().get_image().save_png(path) == OK, "Verification screenshot must save")

func run() -> void:
	root.size = Vector2i(1280, 720)
	lab = (load("res://scenes/lab.tscn") as PackedScene).instantiate() as Control
	root.add_child(lab)
	current_scene = lab
	await create_timer(0.8).timeout
	controller = lab.get("prop_input") as Node
	sound = lab.get("control_audio") as Node
	expect(controller != null and sound != null, "Scene must bind physical controls and their audio")
	if controller == null or sound == null:
		finish()
		return
	sound.connect("played", _played)
	var expected: Array[String] = ["radio.power", "radio.volume", "radio.tuning", "recorder.play", "recorder.stop", "recorder.rewind", "recorder.record", "recorder.level", "lamp.power", "computer.power", "computer.palette", "computer.lock", "computer.knob", "keyboard.space"]
	for row: int in range(4):
		for column: int in range(12):
			expected.append("keyboard.key_%d_%d" % [row, column])
	for id: String in expected:
		expect(_controls().has(id), "Actual visible control must have an interaction: " + id)
		if _controls().has(id):
			expect((_controls()[id] as Dictionary).has("body"), "Control must expose its actual collision body: " + id)
	if not failures.is_empty():
		finish()
		return
	for id: String in ["radio_station", "radio_noise", "tape"]:
		expect(_loop(id) != null, "Device audio channel must exist: " + id)
	if not failures.is_empty():
		finish()
		return
	var viewport: SubViewport = lab.get("scene_view") as SubViewport
	expect(viewport.size == Vector2i(640, 360), "Test must exercise the real 640x360 pixel preset")
	expect((lab.get("print_pass") as Control).visible, "Test must keep the print distortion enabled")
	expect(is_zero_approx(_state("radio.power")) and is_equal_approx(_state("lamp.power"), 1.0), "Devices must start quiet with the lamp on")
	await verify_radio()
	await verify_recorder()
	await verify_lamp_and_capture()
	await verify_keyboard()
	await verify_computer()
	await verify_modal()
	var unique: Dictionary = {}
	for id: String in heard:
		unique[id] = true
	expect(unique.size() >= 7, "Different actions must actually play at least seven distinct sound identities")
	print("DEVICE_AUDIO_PLAYED: ", JSON.stringify(unique.keys()))
	finish()

func verify_radio() -> void:
	await focus("Radio")
	await tap("radio.power")
	expect(_state("radio.power") > 0.5 and (_audible("radio_station") or _audible("radio_noise")), "Power button must start radio reception")
	var before: float = _state("radio.volume")
	var sound_count: int = heard.size()
	await drag("radio.volume", -36, true)
	expect(_state("radio.volume") < before, "Dragging volume left must lower the actual setting")
	expect(heard.size() > sound_count, "Knob movement must play an audible detent")
	await drag("radio.volume", -540, true)
	expect(is_zero_approx(_state("radio.volume")) and not _audible("radio_station") and not _audible("radio_noise"), "Volume must clamp to silent at its lower stop")
	await drag("radio.volume", 540, true)
	expect(is_equal_approx(_state("radio.volume"), 1.0), "Volume must clamp at its upper stop")
	controller.call("set_value", "radio.tuning", 0.5)
	var station_level: float = _loop("radio_station").volume_db
	var noise_level: float = _loop("radio_noise").volume_db
	var pitch: float = _loop("radio_station").pitch_scale
	await drag("radio.tuning", 31, true)
	expect(not is_equal_approx(_state("radio.tuning"), 0.5), "Tuning knob must retain its dragged value")
	expect(not is_equal_approx(station_level, _loop("radio_station").volume_db) or not is_equal_approx(noise_level, _loop("radio_noise").volume_db) or not is_equal_approx(pitch, _loop("radio_station").pitch_scale), "Tuning must change the received station/noise balance")
	expect(str((lab.get("camera") as Node).get("focused_item")) == "Radio", "Releasing a captured knob outside it must preserve the focused view")
	await shot("interactive_radio")
	await tap("radio.power")
	expect(is_zero_approx(_state("radio.power")) and not _loop("radio_station").playing and not _loop("radio_noise").playing, "Radio power off must stop both continuous channels")

func verify_recorder() -> void:
	await focus("Recorder")
	var reels: Node = controller.get("reel_motion") as Node
	expect(reels != null and (reels.get("reels") as Array).size() == 2, "Both actual three-blade discs must be independently movable")
	var counts: Dictionary = reels.get("triangle_counts")
	expect(int(counts["total"]) == int(counts["fixed"]) + int(counts["left"]) + int(counts["right"]) and int(counts["left"]) > 1000 and int(counts["right"]) > 1000, "Moving discs must be a lossless partition of the imported model")
	var left: MeshInstance3D = (reels.get("reels") as Array)[0] as MeshInstance3D
	var right: MeshInstance3D = (reels.get("reels") as Array)[1] as MeshInstance3D
	var original_angle: Vector2 = Vector2(left.rotation.z, right.rotation.z)
	await tap("recorder.play")
	expect(_state("recorder.play") > 0.5 and _loop("tape").playing, "Play button must start the tape")
	await create_timer(0.45).timeout
	expect(float(reels.get("angular_speed")) > 0.0 and not Vector2(left.rotation.z, right.rotation.z).is_equal_approx(original_angle), "Playback must rotate both original discs")
	var level: float = _loop("tape").volume_db
	await drag("recorder.level", -27, true)
	expect(_loop("tape").volume_db < level, "Recorder level knob must change playback volume")
	await tap("recorder.rewind")
	expect(_state("recorder.rewind") > 0.5 and is_zero_approx(_state("recorder.play")) and is_zero_approx(_state("recorder.record")), "Rewind must release the other transport buttons")
	expect(_loop("tape").playing and str(_loop("tape").get_meta("mode", "")) == "rewind", "Rewind must switch to its own continuous sound")
	await create_timer(0.8).timeout
	expect(float(reels.get("angular_speed")) < 0.0, "Rewind must turn both discs in reverse")
	await tap("recorder.record")
	expect(_state("recorder.record") > 0.5 and is_zero_approx(_state("recorder.play")) and is_zero_approx(_state("recorder.rewind")), "Record must release the other transport buttons")
	await shot("interactive_recorder")
	await tap("recorder.stop")
	expect(is_zero_approx(_state("recorder.play")) and is_zero_approx(_state("recorder.rewind")) and is_zero_approx(_state("recorder.record")) and is_zero_approx(_state("recorder.stop")), "Stop must reset the transport and return its own momentary button")
	expect(not _loop("tape").playing, "Stop must stop tape audio immediately")
	await create_timer(0.8).timeout
	var stopped_angle: Vector2 = Vector2(left.rotation.z, right.rotation.z)
	await create_timer(0.12).timeout
	expect(is_zero_approx(float(reels.get("angular_speed"))) and Vector2(left.rotation.z, right.rotation.z).is_equal_approx(stopped_angle), "Stop must bring both discs to rest without resetting their pose")
	await tap("recorder.play")
	await tap("recorder.play")
	expect(is_zero_approx(_state("recorder.play")) and _loop("tape").stream_paused and str(_loop("tape").get_meta("mode", "")) == "pause", "Pressing play again must pause the tape without resetting it")
	await create_timer(0.3).timeout
	expect(is_zero_approx(float(reels.get("angular_speed"))), "Pausing audio must also pause the two discs")
	var paused_at: float = _loop("tape").get_playback_position()
	await tap("recorder.play")
	expect(_state("recorder.play") > 0.5 and not _loop("tape").stream_paused and _loop("tape").get_playback_position() >= paused_at, "Play must resume the paused tape")
	await tap("recorder.stop")

func verify_lamp_and_capture() -> void:
	await focus("Lamp")
	await tap("lamp.power")
	var light: OmniLight3D = controller.get("lamp_light") as OmniLight3D
	expect(is_zero_approx(_state("lamp.power")) and not light.visible, "Lamp switch must actually turn its light off")
	await tap("lamp.power")
	expect(_state("lamp.power") > 0.5 and light.visible, "Lamp switch must turn its light on")
	var original: float = _state("lamp.power")
	var data: Dictionary = _controls()["lamp.power"]
	var pivot: Node3D = data["pivot"] as Node3D
	mouse(control_pixel("lamp.power"), true)
	await process_frame
	controller.call("_notification", NOTIFICATION_APPLICATION_FOCUS_OUT)
	mouse(Vector2(8, 90), false)
	await process_frame
	expect(str(controller.get("active")).is_empty() and is_equal_approx(_state("lamp.power"), original), "Losing focus during a press must release without toggling")
	expect(pivot.position.is_equal_approx(data["rest"] as Vector3), "Cancelled button must return to rest")
	mouse(control_pixel("lamp.power"), true)
	await process_frame
	mouse(Vector2(8, 90), false)
	await process_frame
	expect(is_equal_approx(_state("lamp.power"), original), "Release outside a button must cancel activation")

func verify_keyboard() -> void:
	await focus("Keyboard")
	var desk: Node = lab.get("desk") as Node
	var terminal: Node = desk.get("terminal_ui") as Node
	var password: LineEdit = terminal.get("password_input") as LineEdit
	password.clear()
	var data: Dictionary = _controls()["keyboard.key_1_0"]
	var pivot: Node3D = data["pivot"] as Node3D
	var at: Vector2 = control_pixel("keyboard.key_1_0")
	mouse(at, true)
	await process_frame
	expect(not pivot.position.is_equal_approx(data["rest"] as Vector3), "A physical key must visibly depress while held")
	mouse(control_pixel("keyboard.key_1_0"), false)
	await create_timer(0.2).timeout
	expect(password.text.ends_with("Q"), "Clicking physical Q must enter Q into the existing terminal")
	expect(pivot.position.is_equal_approx(data["rest"] as Vector3), "Released physical key must return to rest")
	await tap("keyboard.space")
	expect(password.text.ends_with("Q "), "Physical spacebar must enter a space")
	var previous_text: String = password.text
	var sound_count: int = heard.size()
	key(KEY_A, 97)
	await process_frame
	expect(password.text == previous_text + "a", "Hardware keyboard input must still reach the terminal")
	expect(heard.size() > sound_count, "Hardware typing must also play the key sound")
	await shot("interactive_keyboard")
	lab.call("end_screen_editing")

func verify_computer() -> void:
	await focus("Computer")
	var desk: Node = lab.get("desk") as Node
	var terminal: Node = desk.get("terminal_ui") as Node
	var was_powered: bool = bool(desk.get("powered"))
	await tap("computer.power")
	await create_timer(0.35).timeout
	expect(bool(desk.get("powered")) != was_powered, "Computer power button must control the actual display")
	await tap("computer.power")
	await create_timer(0.35).timeout
	expect(bool(desk.get("powered")) == was_powered, "Computer power must switch back on")
	var palette: float = _state("computer.palette")
	await tap("computer.palette")
	expect(not is_equal_approx(palette, _state("computer.palette")), "Palette button must change the screen colour mode")
	var brightness: float = float(desk.get("screen_brightness"))
	var screen_on: StandardMaterial3D = desk.get("screen_on") as StandardMaterial3D
	var previous_colour: Color = screen_on.albedo_color
	await drag("computer.knob", -36, true)
	expect(not is_equal_approx(brightness, float(desk.get("screen_brightness"))) and not screen_on.albedo_color.is_equal_approx(previous_colour), "Brightness knob must change both state and the actual display material")
	var editor: TextEdit = terminal.get("editor") as TextEdit
	editor.text = "KEEP THIS LOCAL NOTE"
	terminal.set("unlocked", true)
	await tap("computer.lock")
	expect(not bool(terminal.get("unlocked")) and editor.text == "KEEP THIS LOCAL NOTE", "Lock button must return to the password screen without losing the written text")
	await shot("interactive_computer")

func verify_modal() -> void:
	await focus("Radio")
	var value: float = _state("radio.volume")
	mouse(control_pixel("radio.volume"), true)
	await process_frame
	expect(str(controller.get("active")) == "radio.volume", "Modal cancellation test must begin during a captured drag")
	var camera: Node = lab.get("camera") as Node
	var focused: String = str(camera.get("focused_item"))
	lab.call("open_desk_file", 0)
	await process_frame
	expect(str(controller.get("active")).is_empty(), "Opening a file must cancel a captured device control")
	var reader: Control = lab.get("file_reader") as Control
	expect(reader.visible, "Reading modal must open")
	motion(control_pixel("radio.volume") + Vector2(100, 0), Vector2(100, 0))
	mouse(Vector2(8, 90), false)
	expect(is_equal_approx(_state("radio.volume"), value), "Modal must block changes to controls behind it")
	key(KEY_ESCAPE)
	await process_frame
	expect(not reader.visible and str(camera.get("focused_item")) == focused, "Esc must close the file without dismissing the underlying focused device")

func finish() -> void:
	if failures.is_empty():
		print("DEVICE_CONTROLS_AUDIO_VERIFY: PASS (62 physical controls; real clicks/drags; radio reception; tape transport; lamp; keyboard; display; modal isolation; distinct sounds)")
	else:
		print("DEVICE_CONTROLS_AUDIO_VERIFY: FAIL ", JSON.stringify(failures))
	if lab != null:
		lab.queue_free()
	quit(0 if failures.is_empty() else 1)
