extends Control
## A modal paper reader. Text uses a native 12px CJK pixel font at integer sizes.
signal reading_changed(reading: bool)
signal page_turned(index: int)

const FONT_PATH: String = "res://art/fonts/fusion-pixel-12px-monospaced-zh_hans.woff2"
var story: Dictionary = {}
var page_index: int = 0
var paper: PanelContainer
var body: Label
var chapter: Label
var title_label: Label
var page_number: Label
var previous_button: Button
var next_button: Button
var close_button: Button
var scroll: ScrollContainer
var previous_focus: Control = null
var fade: Tween = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	story = JSON.parse_string(FileAccess.get_file_as_string("res://data/archive_story.json")) as Dictionary
	_build_theme()
	_build_page()
	resized.connect(_layout)
	_layout()
	hide()

func _build_theme() -> void:
	var font: FontFile = load(FONT_PATH) as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling = 1.0
	font.fixed_size = 12
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	var page_theme: Theme = Theme.new()
	page_theme.default_font = font
	page_theme.default_font_size = 24
	page_theme.set_color("font_color", "Label", Color("35435e"))
	page_theme.set_constant("line_spacing", "Label", 6)
	page_theme.set_constant("separation", "VBoxContainer", 12)
	page_theme.set_constant("separation", "HBoxContainer", 16)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("ead5b1") if state == "normal" else Color("d8b5b3")
		if state == "disabled":
			style.bg_color = Color("f5dfb4")
		style.border_color = Color("607caa") if state == "focus" else Color("cba6a2")
		style.set_border_width_all(2 if state == "focus" else 0)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		page_theme.set_stylebox(state, "Button", style)
	page_theme.set_color("font_color", "Button", Color("35435e"))
	page_theme.set_color("font_hover_color", "Button", Color("35435e"))
	page_theme.set_color("font_pressed_color", "Button", Color("784966"))
	page_theme.set_color("font_focus_color", "Button", Color("35435e"))
	page_theme.set_color("font_disabled_color", "Button", Color("baa9a1"))
	theme = page_theme

func _label(node_name: String, text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(node_name: String, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button

func _build_page() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.name = "Backdrop"
	shade.color = Color(0.09, 0.10, 0.18, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	paper = PanelContainer.new()
	paper.name = "Paper"
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	var paper_style: StyleBoxFlat = StyleBoxFlat.new()
	paper_style.bg_color = Color("f5dfb4")
	paper_style.border_color = Color("829bc0")
	paper_style.set_border_width_all(2)
	paper_style.shadow_color = Color(0.05, 0.06, 0.12, 0.4)
	paper_style.shadow_size = 10
	paper_style.shadow_offset = Vector2(10, 12)
	paper_style.content_margin_left = 36
	paper_style.content_margin_right = 36
	paper_style.content_margin_top = 24
	paper_style.content_margin_bottom = 24
	paper.add_theme_stylebox_override("panel", paper_style)
	center.add_child(paper)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Content"
	paper.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	column.add_child(header)
	var archive: Label = _label("Archive", "NORTH / 83    RELAY ARCHIVE", 12)
	archive.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive.add_theme_color_override("font_color", Color("60718e"))
	header.add_child(archive)
	close_button = _button("Close", "放回", close)
	close_button.tooltip_text = "放回文件 · Esc"
	header.add_child(close_button)
	title_label = _label("Title", str(story["title"]), 36)
	column.add_child(title_label)
	chapter = _label("Chapter", "", 24)
	chapter.add_theme_color_override("font_color", Color("a35f7d"))
	column.add_child(chapter)
	var rule: ColorRect = ColorRect.new()
	rule.name = "Rule"
	rule.color = Color("ce8c9d")
	rule.custom_minimum_size.y = 2
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	scroll = ScrollContainer.new()
	scroll.name = "TextScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	body = _label("Story", "", 24)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(body)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(footer)
	previous_button = _button("Previous", "←", _turn.bind(-1))
	previous_button.tooltip_text = "上一页 · ←"
	footer.add_child(previous_button)
	page_number = _label("PageNumber", "", 12)
	footer.add_child(page_number)
	next_button = _button("Next", "→", _turn.bind(1))
	next_button.tooltip_text = "下一页 · →"
	footer.add_child(next_button)

func _layout() -> void:
	if paper == null:
		return
	paper.custom_minimum_size = Vector2(minf(800.0, maxf(280.0, size.x - 48.0)), minf(640.0, maxf(280.0, size.y - 48.0)))
	# Keep prose at 2x native size; smaller windows scroll instead of shrinking the story.
	var compact: bool = size.y < 560.0 or size.x < 760.0
	body.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_font_size_override("font_size", 24 if compact else 36)
	chapter.add_theme_font_size_override("font_size", 12 if compact else 24)

func open_at(index: int) -> void:
	if not visible:
		previous_focus = get_viewport().gui_get_focus_owner()
	page_index = clampi(index, 0, (story["pages"] as Array).size() - 1)
	_update_page()
	show()
	close_button.grab_focus()
	if fade != null and fade.is_valid():
		fade.kill()
	modulate.a = 0.0
	fade = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.16)
	reading_changed.emit(true)

func close() -> void:
	if not visible:
		return
	if fade != null and fade.is_valid():
		fade.kill()
	hide()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()
	else:
		close_button.release_focus()
	reading_changed.emit(false)

func _turn(direction: int) -> void:
	var previous_page: int = page_index
	page_index = clampi(page_index + direction, 0, (story["pages"] as Array).size() - 1)
	_update_page()
	if previous_page != page_index:
		page_turned.emit(page_index)

func _update_page() -> void:
	var pages: Array = story["pages"]
	var page: Dictionary = pages[page_index]
	chapter.text = "%02d / %s" % [page_index + 1, str(page["chapter"])]
	body.text = str(page["body"])
	page_number.text = "%02d / %02d" % [page_index + 1, pages.size()]
	previous_button.disabled = page_index == 0
	next_button.disabled = page_index == pages.size() - 1
	scroll.set_deferred("scroll_vertical", 0)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			close()
		KEY_LEFT:
			_turn(-1)
		KEY_RIGHT:
			_turn(1)
		_:
			return
	get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			close()
			accept_event()
