extends VBoxContainer
## Local conversation prototype. The terminal's reply is deliberately fixed.
signal state_changed
const REPLY: String = "HELLO,WHAT CAN I DO FOR YOU"
const MAX_TURNS: int = 32
var editor: TextEdit
var transcript: TextEdit
var messages: Array[Dictionary] = []
var active: bool = false
var replying: bool = false
var reply_elapsed: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 66)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 3)
	transcript = TextEdit.new()
	transcript.name = "Transcript"
	transcript.editable = false
	transcript.focus_mode = Control.FOCUS_NONE
	transcript.context_menu_enabled = false
	transcript.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	transcript.scroll_past_end_of_file = true
	transcript.custom_minimum_size = Vector2(0, 43)
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.add_theme_font_size_override("font_size", 10)
	transcript.placeholder_text = "LOCAL NODE ONLINE_"
	add_child(transcript)
	editor = TextEdit.new()
	editor.name = "Editor"
	editor.placeholder_text = "> TYPE A MESSAGE_"
	editor.add_theme_color_override("font_placeholder_color", Color("679d79"))
	editor.caret_type = TextEdit.CARET_TYPE_BLOCK
	editor.caret_blink = true
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.custom_minimum_size = Vector2(0, 20)
	editor.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(editor)
	editor.gui_input.connect(_on_editor_input)

func _on_editor_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.keycode not in [KEY_ENTER, KEY_KP_ENTER] or key.shift_pressed:
		return
	# Let the native editor commit an in-progress input-method composition first.
	if editor.has_ime_text():
		return
	editor.accept_event()
	if not key.echo:
		submit()

func submit() -> void:
	if not active or replying:
		return
	var prompt: String = editor.text.strip_edges()
	if prompt.is_empty():
		return
	messages.append({"prompt": prompt, "reply": ""})
	if messages.size() > MAX_TURNS:
		messages.pop_front()
	editor.clear()
	replying = true
	reply_elapsed = 0.0
	_refresh_transcript()
	state_changed.emit()

func _process(delta: float) -> void:
	if not active or not replying:
		return
	reply_elapsed += delta
	var count: int = clampi(int(maxf(0.0, reply_elapsed - 0.22) * 38.0), 0, REPLY.length())
	var latest: Dictionary = messages.back()
	var visible_reply: String = REPLY.left(count)
	if str(latest["reply"]) != visible_reply:
		latest["reply"] = visible_reply
		_refresh_transcript()
	if count >= REPLY.length():
		replying = false
		state_changed.emit()

func _refresh_transcript() -> void:
	var lines: PackedStringArray = []
	for message: Dictionary in messages:
		lines.append("YOU> " + str(message["prompt"]))
		lines.append("NORTH> " + str(message["reply"]))
	transcript.text = "\n".join(lines)
	transcript.set_caret_line(transcript.get_line_count() - 1)
	transcript.set_caret_column(transcript.get_line(transcript.get_line_count() - 1).length())
	# Keep the newest exchange aligned to complete pixel rows.
	transcript.scroll_vertical = float(maxi(0, transcript.get_total_visible_line_count() - 2))
