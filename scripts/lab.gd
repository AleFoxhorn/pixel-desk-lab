extends Control
## Small comparison harness: content, camera, style pipeline and overlay stay separate.

const DeskScene: Script = preload("res://scripts/desk_scene.gd")
const CameraDirector: Script = preload("res://scripts/camera_director.gd")
const FileReader: Script = preload("res://scripts/file_reader.gd")
var file_reader: FileReader
signal physical_key_changed(keycode: int, pressed: bool)
var editing_screen: bool = false
var held_keys: Dictionary = {}
var last_screen_pixel: Vector2 = Vector2.ZERO
var screen_mouse_down: bool = false

var scene_view: SubViewport
var image: TextureRect
var desk: DeskScene
var camera: CameraDirector
var post: ShaderMaterial
var view_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []
var mode: int = 3
var status: Label
var dither_button: CheckButton
var resolution: OptionButton
var hover_action: String = ""
var overlay: Control
var captures: String = "res://verification"
var capture_mode: bool = false
var reference_style: bool = true
var print_pass: ColorRect
var print_material: ShaderMaterial
var print_option: OptionButton
var print_strength: float = 1.0
var style_button: Button
var prop_input: Node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_pipeline()
	_build_interface()
	var reader_layer: CanvasLayer = CanvasLayer.new()
	reader_layer.name = "ReadingLayer"
	reader_layer.layer = 10
	add_child(reader_layer)
	file_reader = FileReader.new()
	file_reader.name = "FileReader"
	reader_layer.add_child(file_reader)
	file_reader.reading_changed.connect(_set_reading)
	get_viewport().size_changed.connect(_layout_image)
	_layout_image()
	apply_playtest_style()
	select_view(4, true)
	prop_input = preload("res://scripts/prop_interactions.gd").new()
	prop_input.name = "PropInteractions"
	prop_input.setup(self)
	add_child(prop_input)
	if "--verify" in OS.get_cmdline_user_args():
		capture_mode = true
		_verify.call_deferred()

func apply_playtest_style() -> void:
	# One launch preset applies the same palette, blur and vignette to all imported props.
	style_button.set_pressed_no_signal(true)
	dither_button.set_pressed_no_signal(true)
	resolution.select(0)
	print_option.select(1)
	post.set_shader_parameter("dither_enabled", true)
	post.set_shader_parameter("dither_strength", 0.03)
	set_reference_style(true)
	set_mode(3)
	set_print_preset(1)

func _build_pipeline() -> void:
	# Models, lighting, camera, view markers and post-process now live in saved scenes.
	scene_view = get_node("SceneViewport") as SubViewport
	desk = scene_view.get_node("DeskWorld") as DeskScene
	camera = desk.get_node("Camera") as CameraDirector
	image = get_node("StyledImage") as TextureRect
	image.texture = scene_view.get_texture()
	post = image.material as ShaderMaterial
	post.set_shader_parameter("dither_strength", 0.03)
	print_pass = ColorRect.new()
	print_pass.name = "PrintPass"
	print_pass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print_material = ShaderMaterial.new()
	print_material.shader = preload("res://shaders/print.gdshader")
	print_pass.material = print_material
	add_child(print_pass)

func _build_interface() -> void:
	var ui_theme: Theme = Theme.new()
	var font: Font = preload("res://scripts/terminal_font.gd").create_font()
	ui_theme.default_font = font
	ui_theme.default_font_size = 14
	ui_theme.set_color("font_color", "Label", Color("bac7bd"))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color("17292e") if state == "normal" else Color("34514d")
		box.border_color = Color("47635c") if state != "focus" else Color("d4c396")
		box.set_border_width_all(1)
		box.set_corner_radius_all(4)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 9
		box.content_margin_bottom = 9
		ui_theme.set_stylebox(state, "Button", box)
		ui_theme.set_stylebox(state, "OptionButton", box)
	ui_theme.set_color("font_color", "Button", Color("a6b9ac"))
	ui_theme.set_color("font_pressed_color", "Button", Color("f2ddb1"))
	theme = ui_theme
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var title: Label = Label.new()
	title.text = "NORTH / 83"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("e3d4af"))
	top.add_child(title)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var view_group: ButtonGroup = ButtonGroup.new()
	var view_names: Array[String] = ["Front", "侧面", "背面", "屏幕特写", "环境"]
	for index: int in range(view_names.size()):
		var button: Button = _button(view_names[index], view_group)
		button.pressed.connect(select_view.bind(index, false))
		view_buttons.append(button)
		top.add_child(button)
	var middle: Control = Control.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)
	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	column.add_child(bottom)
	status = Label.new()
	status.text = "点击屏幕输入"
	status.add_theme_color_override("font_color", Color("a0b2a5"))
	bottom.add_child(status)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	bottom.add_child(row)
	var mode_group: ButtonGroup = ButtonGroup.new()
	var mode_names: Array[String] = ["原始", "仅材质", "仅后期", "综合"]
	for index: int in range(mode_names.size()):
		var button: Button = _button(mode_names[index], mode_group)
		button.pressed.connect(set_mode.bind(index))
		mode_buttons.append(button)
		row.add_child(button)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	style_button = Button.new()
	style_button.text = "参考配色"
	style_button.toggle_mode = true
	style_button.button_pressed = true
	style_button.toggled.connect(set_reference_style)
	row.add_child(style_button)
	print_option = OptionButton.new()
	for label: String in ["清晰", "旧印刷 · 轻", "旧印刷 · 重"]:
		print_option.add_item(label)
	print_option.selected = 1
	print_option.item_selected.connect(set_print_preset)
	row.add_child(print_option)
	dither_button = CheckButton.new()
	dither_button.text = "抖色"
	dither_button.button_pressed = true
	dither_button.toggled.connect(func(value: bool) -> void: post.set_shader_parameter("dither_enabled", value))
	row.add_child(dither_button)
	resolution = OptionButton.new()
	resolution.add_item("640 × 360")
	resolution.add_item("480 × 270")
	resolution.add_item("320 × 180")
	resolution.add_item("1280 × 720")
	resolution.selected = 0
	resolution.item_selected.connect(func(_index: int) -> void: _update_resolution())
	row.add_child(resolution)

func set_print_preset(index: int) -> void:
	var strengths: Array[float] = [0.0, 0.45, 1.65]
	print_strength = strengths[index]
	print_material.set_shader_parameter("strength", print_strength)
	print_pass.visible = mode >= 2 and print_strength > 0.0

func set_reference_style(enabled: bool) -> void:
	reference_style = enabled
	desk.set_reference_style(enabled)
	post.set_shader_parameter("reference_style", enabled)

func _button(text: String, group: ButtonGroup) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	return button

func _layout_image() -> void:
	var window_size: Vector2 = get_viewport_rect().size
	var fit: float = minf(window_size.x / 16.0, window_size.y / 9.0)
	image.size = Vector2(16, 9) * fit
	image.position = (window_size - image.size) * 0.5
	print_pass.position = image.position
	print_pass.size = image.size
	print_material.set_shader_parameter("image_scale", image.size / window_size)

func select_view(index: int, immediate: bool = false, side: int = 0) -> void:
	if prop_input != null:
		prop_input.cancel()
	end_screen_editing()
	camera.go_to(index, immediate, side)
	view_buttons[index].button_pressed = true

func set_mode(index: int) -> void:
	mode = index
	desk.set_toon(index == 1 or index == 3)
	post.set_shader_parameter("enabled", index >= 2)
	mode_buttons[index].button_pressed = true
	dither_button.disabled = index < 2
	resolution.disabled = index < 2
	print_option.disabled = index < 2
	set_print_preset(print_option.selected)
	_update_resolution()

func _update_resolution() -> void:
	var sizes: Array[Vector2i] = [Vector2i(640, 360), Vector2i(480, 270), Vector2i(320, 180), Vector2i(1280, 720)]
	scene_view.size = sizes[resolution.selected] if mode >= 2 else Vector2i(1280, 720)
	print_material.set_shader_parameter("source_size", Vector2(scene_view.size))

func _unhandled_input(event: InputEvent) -> void:
	if file_reader != null and file_reader.visible:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			var screen_pixel: Vector2 = screen_coordinates(button.position)
			if desk.powered and screen_pixel.x >= 0:
				if camera.active_view != 0 and camera.active_view != 3:
					select_view(3)
				editing_screen = true
				desk.terminal_ui.begin_editing()
				forward_screen_mouse(event, screen_pixel)
				get_viewport().set_input_as_handled()
				return
			end_screen_editing()
			var hit: Dictionary = pick(button.position)
			if not hit.is_empty():
				var collider: CollisionObject3D = hit["collider"]
				if collider.has_meta("action"):
					var target: Node = desk
					if collider.has_meta("interaction_target"):
						target = collider.get_node_or_null(collider.get_meta("interaction_target") as NodePath)
					if target != null and target.has_method("interact"):
						target.call("interact", str(collider.get_meta("action")))
						get_viewport().set_input_as_handled()
						return
			var region: Vector2i = computer_view_at(button.position)
			if region.x >= 0:
				select_view(region.x, false, region.y)
				get_viewport().set_input_as_handled()
			elif camera.active_view in [0, 1, 2, 3]:
				select_view(4)
				get_viewport().set_input_as_handled()

func computer_view_at(at: Vector2) -> Vector2i:
	var hit: Dictionary = pick(at, 16)
	if hit.is_empty():
		return Vector2i(-1, 0)
	var housing: Node3D = (hit["collider"] as Node).get_parent() as Node3D
	var point: Vector3 = housing.to_local(hit["position"])
	var bounds: AABB = (housing as MeshInstance3D).get_aabb()
	point = (point - bounds.get_center()) / bounds.size
	var normal: Vector3 = housing.global_basis.inverse() * (hit["normal"] as Vector3)
	# Front edges lead around the computer; side rear edges continue to its back.
	var side: int = 1 if point.x >= 0 else -1
	if absf(normal.x) > 0.5:
		return Vector2i(2, 0) if point.z < -0.2375 else Vector2i(1, side)
	if normal.z < -0.5:
		return Vector2i(1, side) if absf(point.x) > 0.3455 else Vector2i(2, 0)
	if absf(point.x) > 0.3818:
		return Vector2i(1, side)
	return Vector2i(0, 0)

func _input(event: InputEvent) -> void:
	if file_reader != null and file_reader.visible:
		return
	if not editing_screen or not desk.powered:
		return
	if event is InputEventKey:
		if desk.terminal_ui.booting:
			get_viewport().set_input_as_handled()
			return
		var key: InputEventKey = event
		if not key.echo:
			var physical: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
			if key.pressed:
				held_keys[physical] = true
			else:
				held_keys.erase(physical)
			physical_key_changed.emit(physical, key.pressed)
		desk.terminal_view.push_input(event, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouse:
		var pointer: InputEventMouse = event
		var pixel: Vector2 = screen_coordinates(pointer.position)
		if pixel.x >= 0 or (screen_mouse_down and event is InputEventMouseButton and not (event as InputEventMouseButton).pressed):
			forward_screen_mouse(event, pixel if pixel.x >= 0 else last_screen_pixel)
			get_viewport().set_input_as_handled()

func forward_screen_mouse(event: InputEvent, pixel: Vector2) -> void:
	last_screen_pixel = pixel
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		screen_mouse_down = (event as InputEventMouseButton).pressed
	var forwarded: InputEventMouse = event.duplicate() as InputEventMouse
	forwarded.position = pixel
	forwarded.global_position = pixel
	if forwarded is InputEventMouseMotion:
		(forwarded as InputEventMouseMotion).relative = Vector2.ZERO
	desk.terminal_view.push_input(forwarded, true)

func end_screen_editing() -> void:
	for physical: int in held_keys:
		physical_key_changed.emit(physical, false)
	held_keys.clear()
	editing_screen = false
	screen_mouse_down = false
	if desk != null and desk.terminal_ui != null:
		desk.terminal_ui.end_editing()

func open_desk_file(index: int) -> void:
	end_screen_editing()
	file_reader.open_at(index)

func _set_reading(reading: bool) -> void:
	overlay.visible = not reading

func image_uv(screen_position: Vector2) -> Vector2:
	var uv: Vector2 = (screen_position - image.global_position) / image.size
	if print_pass.visible:
		# Share print.gdshader's pixel centre and warp for screen UI and every ray pick.
		var source_size: Vector2 = Vector2(scene_view.size)
		var pixel_uv: Vector2 = ((uv * source_size).floor() + Vector2(0.5, 0.5)) / source_size
		var centered: Vector2 = pixel_uv - Vector2(0.5, 0.5)
		uv = pixel_uv + centered * centered.length_squared() * 0.018 * print_strength
		uv.x += sin(pixel_uv.y * 112.0) * 0.00045 * print_strength
	return uv.clamp(Vector2.ZERO, Vector2.ONE)

func screen_coordinates(screen_position: Vector2) -> Vector2:
	if not image.get_global_rect().has_point(screen_position):
		return Vector2(-1, -1)
	var pixel: Vector2 = image_uv(screen_position) * Vector2(scene_view.size)
	var origin: Vector3 = camera.project_ray_origin(pixel)
	var direction: Vector3 = camera.project_ray_normal(pixel)
	if (desk.screen.global_basis.inverse() * direction).z >= -0.0001:
		return Vector2(-1, -1)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 40.0, desk.SCREEN_COLLISION_LAYER)
	var hit: Dictionary = scene_view.find_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2(-1, -1)
	var point: Vector3 = desk.screen.to_local(hit["position"])
	var uv: Vector2 = Vector2(point.x / desk.screen_size.x + 0.5, 0.5 - point.y / desk.screen_size.y)
	return uv * Vector2(desk.ScreenSurface.TEXTURE_SIZE)

func pick(screen_position: Vector2, mask: int = 1) -> Dictionary:
	if not image.get_global_rect().has_point(screen_position):
		return {}
	var uv: Vector2 = image_uv(screen_position)
	var viewport_pixel: Vector2 = uv * Vector2(scene_view.size)
	var origin: Vector3 = camera.project_ray_origin(viewport_pixel)
	var direction: Vector3 = camera.project_ray_normal(viewport_pixel)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 30.0, mask)
	return scene_view.find_world_3d().direct_space_state.intersect_ray(query)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		end_screen_editing()

func _process(_delta: float) -> void:
	if editing_screen and desk != null and not desk.powered:
		end_screen_editing()
	if capture_mode or desk == null or status == null:
		return
	if file_reader != null and file_reader.visible:
		return
	var hit: Dictionary = pick(get_global_mouse_position())
	hover_action = ""
	if not hit.is_empty():
		var collider: CollisionObject3D = hit["collider"]
		hover_action = str(collider.get_meta("action", ""))
	var names: Dictionary = {"power": "电源 · 点击切换", "knob": "旋钮 · 转动后复位", "tray": "托盘 · 推出后复位", "desk_drawer": "抽屉 · 点击开合", "desk_file_0": "文件 · 点击阅读", "desk_file_1": "文件 · 点击阅读"}
	status.text = "正在编辑" if editing_screen else str(names.get(hover_action, "点击屏幕输入"))
	image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hover_action.is_empty() else Control.CURSOR_ARROW

func _shot(file_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var error: Error = picture.save_png(ProjectSettings.globalize_path(captures.path_join(file_name + ".png")))
	assert(error == OK, "Failed to save verification screenshot")

func _verify() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(captures))
	await get_tree().create_timer(0.8).timeout
	for index: int in range(4):
		set_mode(index)
		await get_tree().create_timer(0.2).timeout
		await _shot("mode_%d" % index)
	set_mode(3)
	for index: int in range(1, 4):
		select_view(index)
		await get_tree().create_timer(0.5).timeout
		await _shot("move_%d" % index)
		await get_tree().create_timer(0.7).timeout
		assert(camera.active_view == index)
		await _shot("view_%d" % index)
	select_view(0, true)
	await get_tree().create_timer(0.2).timeout
	var power_rest: Vector3 = desk.power_button.position
	var tray_rest: Vector3 = desk.tray.position
	var original_power: bool = desk.powered
	await desk.interact("power")
	assert(desk.powered != original_power)
	assert(desk.power_button.position.is_equal_approx(power_rest))
	await _shot("power_off")
	await desk.interact("power")
	await desk.interact("knob")
	assert(is_zero_approx(desk.tuning_knob.rotation.z))
	desk.interact("tray")
	await get_tree().create_timer(0.65).timeout
	assert(desk.tray.position.z > tray_rest.z + 0.5)
	await _shot("tray_open")
	await get_tree().create_timer(1.2).timeout
	assert(desk.tray.position.is_equal_approx(tray_rest))
	for body: Node3D in [desk.power_button, desk.tuning_knob, desk.tray]:
		var viewport_point: Vector2 = camera.unproject_position(body.global_position)
		var window_point: Vector2 = image.global_position + viewport_point / Vector2(scene_view.size) * image.size
		var hit: Dictionary = pick(window_point)
		assert(not hit.is_empty(), "Screen/viewport picking coordinates must agree")
	await _shot("final")
	style_button.button_pressed = false
	await _shot("legacy_palette")
	style_button.button_pressed = true
	assert(reference_style)
	await _shot("reference_palette")
	set_print_preset(0)
	await _shot("print_off")
	set_print_preset(2)
	await _shot("print_strong")
	set_print_preset(1)
	await _shot("print_light")
	print("LAB_VERIFY_OK: 4 render modes, 3 camera transitions, power state, knob/tray reset, picking")
	get_tree().quit()
