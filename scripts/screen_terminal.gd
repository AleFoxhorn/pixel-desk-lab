extends Control
## Native text editing lives independently of the replaceable 3D display.
const PASSWORD: String = "HELLO WORLD"
var unlocked: bool = false
var booting: bool = false
var boot_elapsed: float = 0.0
var editing_requested: bool = false
var boot_label: Label
const LOGO_DURATION: float = 1.4
const CHECK_DURATION: float = 3.4
const BOOT_DURATION: float = LOGO_DURATION + CHECK_DURATION
var content_panel: MarginContainer
var boot_emblem: Control
var boot_audio: Node
var password_input: LineEdit
var lock_area: VBoxContainer
var unlock_button: Button
var access_status: Label

var editor: TextEdit
var count_label: Label

func _ready() -> void:
	boot_audio = preload("res://scripts/boot_audio.gd").new()
	boot_audio.name = "BootAudio"
	add_child(boot_audio)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ui_theme: Theme = Theme.new()
	var font: Font = preload("res://scripts/terminal_font.gd").create_font(true)
	ui_theme.default_font = font
	ui_theme.default_font_size = 12
	ui_theme.set_color("font_color", "TextEdit", Color("9bcea8"))
	ui_theme.set_color("caret_color", "TextEdit", Color("b3e3a6"))
	ui_theme.set_color("selection_color", "TextEdit", Color("315447"))
	for state: String in ["normal", "read_only", "focus"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color("0c1112")
		box.border_color = Color("a6caa0") if state == "focus" else Color("41796b")
		box.set_border_width_all(0)
		box.set_corner_radius_all(0)
		box.content_margin_left = 0
		box.content_margin_top = 1
		ui_theme.set_stylebox(state, "TextEdit", box)
		ui_theme.set_stylebox(state, "LineEdit", box)
	for state: String in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		var scroll_box: StyleBoxFlat = StyleBoxFlat.new()
		scroll_box.bg_color = Color("294d39") if state.begins_with("grabber") else Color("0c1112")
		scroll_box.content_margin_left = 1
		scroll_box.content_margin_right = 1
		ui_theme.set_stylebox(state, "VScrollBar", scroll_box)
		ui_theme.set_stylebox(state, "HScrollBar", scroll_box)
	ui_theme.set_color("font_color", "LineEdit", Color("9bcea8"))
	ui_theme.set_color("caret_color", "LineEdit", Color("b3e3a6"))
	ui_theme.set_color("font_placeholder_color", "LineEdit", Color("679d79"))
	ui_theme.set_color("selection_color", "LineEdit", Color("315447"))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var button_box: StyleBoxFlat = StyleBoxFlat.new()
		button_box.bg_color = Color("0c1112")
		button_box.border_color = Color("9bcea8")
		button_box.border_width_bottom = 1 if state == "focus" else 0
		ui_theme.set_stylebox(state, "Button", button_box)
	ui_theme.set_color("font_color", "Button", Color("9bcea8"))
	ui_theme.set_color("font_hover_color", "Button", Color("c0ecc0"))
	ui_theme.set_color("font_pressed_color", "Button", Color("c0ecc0"))
	theme = ui_theme
	var background: ColorRect = ColorRect.new()
	background.color = Color("0c1112")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	content_panel = margin
	margin.position = Vector2(58, 42)
	margin.size = Vector2(221, 90)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var heading: Label = Label.new()
	heading.text = "NORTH / RELAY SYSTEMS"
	heading.add_theme_color_override("font_color", Color("9bcea8"))
	heading.add_theme_font_size_override("font_size", 11)
	column.add_child(heading)
	lock_area = VBoxContainer.new()
	lock_area.name = "AccessLock"
	lock_area.custom_minimum_size = Vector2(0, 66)
	lock_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lock_area.add_theme_constant_override("separation", 4)
	column.add_child(lock_area)
	access_status = Label.new()
	access_status.text = "ACCESS LOCKED"
	access_status.add_theme_color_override("font_color", Color("679d79"))
	lock_area.add_child(access_status)
	password_input = LineEdit.new()
	password_input.name = "Password"
	password_input.placeholder_text = "PASSWORD_"
	password_input.secret = true
	password_input.secret_character = "*"
	password_input.max_length = 64
	password_input.caret_blink = true
	password_input.keep_editing_on_text_submit = true
	password_input.custom_minimum_size = Vector2(0, 16)
	lock_area.add_child(password_input)
	unlock_button = Button.new()
	unlock_button.text = "[ UNLOCK ]"
	unlock_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	unlock_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lock_area.add_child(unlock_button)
	unlock_button.pressed.connect(_attempt_unlock)
	password_input.text_submitted.connect(func(_value: String) -> void: _attempt_unlock())
	password_input.text_changed.connect(_password_changed)
	editor = TextEdit.new()
	editor.name = "Editor"
	editor.placeholder_text = "01 / WAITING FOR INPUT_"
	editor.add_theme_color_override("font_placeholder_color", Color("679d79"))
	editor.caret_type = TextEdit.CARET_TYPE_BLOCK
	editor.caret_blink = true
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.custom_minimum_size = Vector2(0, 66)
	editor.scroll_fit_content_height = false
	editor.visible = false
	column.add_child(editor)
	boot_label = Label.new()
	boot_label.name = "BootSequence"
	boot_label.custom_minimum_size = Vector2(0, 66)
	boot_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boot_label.add_theme_color_override("font_color", Color("9bcea8"))
	boot_label.add_theme_font_size_override("font_size", 10)
	boot_label.text = "ACCESS GRANTED\n\nMEMORY CHECK ........ OK\nRELAY LINK .......... OK\nLOCAL NODE .......... ONLINE"
	boot_label.hide()
	column.add_child(boot_label)
	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color("679d79"))
	column.add_child(count_label)
	boot_emblem = preload("res://scripts/boot_emblem.gd").new()
	boot_emblem.name = "BootEmblem"
	boot_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boot_emblem)
	boot_emblem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boot_emblem.hide()
	editor.text_changed.connect(_update_count)
	_update_count()

func _update_count() -> void:
	if booting:
		return
	if not unlocked:
		count_label.text = "ENTER / UNLOCK"
		return
	count_label.text = "LOCAL NODE: ONLINE / %03d / LINK: --" % editor.text.length()

func begin_editing() -> void:
	editing_requested = true
	if booting:
		return
	if unlocked:
		editor.grab_focus()
	else:
		password_input.grab_focus()

func end_editing() -> void:
	editing_requested = false
	editor.release_focus()
	password_input.release_focus()
	unlock_button.release_focus()

func _password_changed(_value: String) -> void:
	if _value.is_empty():
		return
	access_status.text = "ACCESS LOCKED"
	_update_count()

func _attempt_unlock() -> void:
	if unlocked or booting:
		return
	if password_input.text != PASSWORD:
		access_status.text = "ACCESS DENIED"
		password_input.clear()
		# clear() may emit text_changed, so set failure feedback afterwards.
		access_status.text = "ACCESS DENIED"
		count_label.text = "INCORRECT PASSWORD / TRY AGAIN"
		password_input.grab_focus()
		return
	boot_audio.play_unlock()
	booting = true
	boot_elapsed = 0.0
	content_panel.hide()
	boot_emblem.modulate.a = 0.0
	boot_emblem.set_progress(0.0)
	boot_emblem.show()
	password_input.clear()
	password_input.release_focus()
	unlock_button.release_focus()
	lock_area.hide()
	boot_label.visible_characters = 0
	boot_label.show()
	count_label.text = "[....................] 000%"

func _process(delta: float) -> void:
	if not booting:
		return
	boot_elapsed = minf(boot_elapsed + delta, BOOT_DURATION)
	if boot_elapsed < LOGO_DURATION:
		boot_emblem.set_progress(boot_elapsed / LOGO_DURATION)
		boot_emblem.modulate.a = minf(minf(boot_elapsed / 0.18, (LOGO_DURATION - boot_elapsed) / 0.22), 1.0)
		return
	boot_emblem.hide()
	content_panel.show()
	var check_elapsed: float = boot_elapsed - LOGO_DURATION
	# Type out diagnostic lines, then hold the completed result briefly.
	boot_label.visible_characters = int(maxf(0.0, check_elapsed - 0.12) * 47.0)
	boot_label.modulate.a = minf(1.0, check_elapsed / 0.18)
	var progress: float = check_elapsed / CHECK_DURATION
	var blocks: int = mini(20, int(progress * 20))
	count_label.text = "[%s%s] %03d%%" % ["=".repeat(blocks), ".".repeat(20 - blocks), int(progress * 100)]
	if boot_elapsed >= BOOT_DURATION:
		booting = false
		unlocked = true
		boot_label.hide()
		editor.show()
		_update_count()
		if editing_requested:
			editor.grab_focus()
