extends "res://tools/verify_desk_drawer.gd"
## Read both physical files through real input; verify modal isolation and CJK glyphs.

func click_at(pixel: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = pixel
	press.global_position = pixel
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)

func key(code: Key) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)

func file_pixel(file_name: String) -> Vector2:
	var camera: Camera3D = lab.get("camera") as Camera3D
	var file: Node3D = drawer.get_node("Slide/Files/" + file_name + "/PaperHit") as Node3D
	var viewport: SubViewport = lab.get("scene_view") as SubViewport
	var image: TextureRect = lab.get("image") as TextureRect
	var target_uv: Vector2 = camera.unproject_position(file.global_position) / Vector2(viewport.size)
	var uv: Vector2 = target_uv
	for iteration: int in range(5):
		uv += target_uv - (lab.call("image_uv", image.global_position + uv * image.size) as Vector2)
	return image.global_position + uv * image.size

func check_layout(reader: Control) -> void:
	var paper: Control = reader.get("paper") as Control
	var page_rect: Rect2 = paper.get_global_rect()
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(page_rect), "Paper must fit within the viewport")
	for member: String in ["close_button", "previous_button", "next_button", "page_number", "title_label", "chapter", "scroll"]:
		var control: Control = reader.get(member) as Control
		check(page_rect.encloses(control.get_global_rect()), "Reader control must fit within paper: " + member)
	var scroll: ScrollContainer = reader.get("scroll") as ScrollContainer
	var body: Label = reader.get("body") as Label
	print("READER_LAYOUT: viewport=", root.size, " paper=", page_rect, " text_lines=", body.get_line_count(), " body_height=", body.size.y, " visible_height=", scroll.size.y)

func verify() -> void:
	root.size = Vector2i(1280, 720)
	lab = (load("res://scenes/lab.tscn") as PackedScene).instantiate() as Control
	root.add_child(lab)
	current_scene = lab
	await create_timer(0.4).timeout
	drawer = lab.get_node("SceneViewport/DeskWorld/CabinEnvironment/DeskDrawer") as Node3D
	var blue_hit: StaticBody3D = drawer.get_node("Slide/Files/BlueFile/PaperHit") as StaticBody3D
	var rose_hit: StaticBody3D = drawer.get_node("Slide/Files/RoseFile/PaperHit") as StaticBody3D
	check(blue_hit.collision_layer == 0 and rose_hit.collision_layer == 0, "Closed drawer must not expose file hit areas")
	click_handle()
	await create_timer(1.0).timeout
	check(blue_hit.collision_layer == 1 and rose_hit.collision_layer == 1, "Files must become interactive after opening")
	var hit: Dictionary = lab.call("pick", file_pixel("BlueFile"))
	check(hit.get("collider") == blue_hit, "Blue file must be picked at its rendered paper")
	click_at(file_pixel("BlueFile"))
	var reader: Control = lab.get("file_reader") as Control
	check(reader.visible and int(reader.get("page_index")) == 0, "Blue file must open the first story page")
	check(not (lab.get("overlay") as Control).visible, "Reading must hide the scene toolbar")
	await create_timer(0.25).timeout
	check_layout(reader)
	var body: Label = reader.get("body") as Label
	check(body.text.contains("木星总站"), "First page must contain the original novel")
	var font: FontFile = body.get_theme_font("font") as FontFile
	check(font != null and font.antialiasing == TextServer.FONT_ANTIALIASING_NONE and font.fixed_size == 12, "Story must use a native unfiltered pixel font")
	var story: Dictionary = reader.get("story")
	var all_text: String = str(story["title"]) + "放回←→"
	for page: Dictionary in story["pages"]:
		all_text += str(page["chapter"]) + str(page["body"])
	for character: String in all_text:
		if character != "\n":
			check(font.has_char(character.unicode_at(0)), "Pixel font must include every story glyph: " + character)
	await shot("file_reading_page_1")
	# Paper clicks stay in the reader; they must not activate the scene behind it.
	click_at(body.get_global_rect().position + Vector2(24, 24))
	check(reader.visible and bool(drawer.get("is_open")), "Text clicks must keep the modal open and leave the drawer alone")
	var next: Button = reader.get("next_button") as Button
	click_at(next.get_global_rect().get_center())
	check(int(reader.get("page_index")) == 1 and body.text.contains("母亲"), "Next button must show the continuation")
	key(KEY_LEFT)
	check(int(reader.get("page_index")) == 0, "Left key must turn back")
	key(KEY_RIGHT)
	key(KEY_RIGHT)
	check(int(reader.get("page_index")) == 1, "Right key must stop at the final page")
	await process_frame
	check_layout(reader)
	await shot("file_reading_page_2")
	key(KEY_ESCAPE)
	check(not reader.visible and bool(drawer.get("is_open")), "Esc must put the paper back into the open drawer")
	check((lab.get("overlay") as Control).visible, "Closing must restore the scene toolbar")
	click_at(file_pixel("RoseFile"))
	check(reader.visible and int(reader.get("page_index")) == 1, "Rose file must open its own story page")
	var close: Button = reader.get("close_button") as Button
	click_at(close.get_global_rect().get_center())
	check(not reader.visible, "Put-back button must close the reader")
	click_at(file_pixel("BlueFile"))
	root.content_scale_size = Vector2i(960, 540)
	root.size = Vector2i(960, 540)
	await process_frame
	await process_frame
	check_layout(reader)
	check(body.get_theme_font_size("font_size") == 24, "Compact view must keep prose at readable 2x native size")
	await shot("file_reading_compact")
	click_at(Vector2(12, 12))
	check(not reader.visible and bool(drawer.get("is_open")), "Backdrop must dismiss without clicking through")
	drawer.call("set_open", false)
	await create_timer(0.8).timeout
	check(blue_hit.collision_layer == 0 and rose_hit.collision_layer == 0, "Closing must disable both file hit areas")
	print("FILE_READER_CHECK_OK: two physical files, full CJK coverage, mouse/keyboard paging, modal isolation, close/return, two viewport sizes")
	lab.queue_free()
	await process_frame
	quit()
