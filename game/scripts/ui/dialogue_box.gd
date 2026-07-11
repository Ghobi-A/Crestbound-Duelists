extends CanvasLayer
class_name DialogueBox
## Minimal reusable data-driven dialogue box.
##
## Dialogue files are JSON: { "key": [ {"speaker": "...", "lines": ["..."]} ] }.
## A key maps to a sequence of entries (a short conversation); each entry
## has a speaker and one or more lines. Advance with the interact action.
## Emits dialogue_finished(key) when the sequence ends.

signal dialogue_finished(key: String)

var active := false

var _dialogue_data: Dictionary = {}
var _current_key := ""
var _entries: Array = []
var _entry_index := 0
var _line_index := 0

var _panel: ColorRect
var _speaker_label: Label
var _text_label: Label
var _advance_label: Label


func _ready() -> void:
	layer = 10
	_panel = ColorRect.new()
	_panel.color = PlaceholderPalette.BG_PANEL
	_panel.position = Vector2(4, 132)
	_panel.size = Vector2(312, 44)
	add_child(_panel)

	var border := ColorRect.new()
	border.color = PlaceholderPalette.PANEL_BORDER
	border.position = Vector2(0, 0)
	border.size = Vector2(312, 1)
	_panel.add_child(border)

	_speaker_label = Label.new()
	_speaker_label.position = Vector2(6, 2)
	_speaker_label.size = Vector2(300, 10)
	_speaker_label.add_theme_font_size_override("font_size", 8)
	_speaker_label.add_theme_color_override("font_color", PlaceholderPalette.TEXT_WARN)
	_panel.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.position = Vector2(6, 12)
	_text_label.size = Vector2(300, 30)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 8)
	_text_label.add_theme_color_override("font_color", PlaceholderPalette.TEXT_MAIN)
	_panel.add_child(_text_label)

	_advance_label = Label.new()
	_advance_label.text = "v"
	_advance_label.position = Vector2(298, 32)
	_advance_label.add_theme_font_size_override("font_size", 8)
	_advance_label.add_theme_color_override("font_color", PlaceholderPalette.TEXT_DIM)
	_panel.add_child(_advance_label)

	visible = false


func load_file(path: String) -> void:
	_dialogue_data = {}
	if not FileAccess.file_exists(path):
		push_error("Dialogue file not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Invalid dialogue JSON in %s: %s" % [path, json.get_error_message()])
		return
	_dialogue_data = json.data


func has_key(key: String) -> bool:
	return _dialogue_data.has(key)


func play(key: String) -> void:
	if active:
		return
	if not _dialogue_data.has(key):
		push_error("Unknown dialogue key '%s'." % key)
		return
	_current_key = key
	_entries = _dialogue_data[key]
	_entry_index = 0
	_line_index = 0
	active = true
	visible = true
	_show_current_line()


func _show_current_line() -> void:
	var entry: Dictionary = _entries[_entry_index]
	_speaker_label.text = entry.get("speaker", "")
	var lines: Array = entry.get("lines", [])
	_text_label.text = str(lines[_line_index])


func _advance() -> void:
	var entry: Dictionary = _entries[_entry_index]
	var lines: Array = entry.get("lines", [])
	_line_index += 1
	if _line_index < lines.size():
		_show_current_line()
		return
	_entry_index += 1
	_line_index = 0
	if _entry_index < _entries.size():
		_show_current_line()
		return
	# Sequence finished.
	active = false
	visible = false
	var finished_key := _current_key
	_current_key = ""
	dialogue_finished.emit(finished_key)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_advance()
