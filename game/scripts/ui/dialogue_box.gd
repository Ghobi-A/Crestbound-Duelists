extends CanvasLayer
class_name DialogueBox
## Minimal reusable data-driven dialogue box.
##
## Dialogue files are JSON: { "key": [ {"speaker": "...", "lines": [...],
## "portrait": "..."} ] }. A key maps to a sequence of entries (a short
## conversation); each entry has a speaker and one or more lines.
## "portrait" is optional and names a sprite_key under assets/portraits/;
## "expression" selects neutral/determined/injured/surprised/intense and
## gracefully falls back to neutral when that authored crop is unavailable.
## (e.g. "elara", "townsfolk/farmboy") — an entry with no portrait, or one
## naming art that was never authored, just shows text at full width, so
## adding a portrait later is additive and never required. Advance with
## the interact action. Emits dialogue_finished(key) when the sequence ends.

signal dialogue_finished(key: String)

const PORTRAIT_PATH := "res://assets/portraits/%s/neutral.png"
const PORTRAIT_SIZE := Vector2(34, 38)
const PORTRAIT_MARGIN := Vector2(4, 3)
const TEXT_MARGIN_RIGHT := 6.0

var active := false

var _dialogue_data: Dictionary = {}
var _current_key := ""
var _entries: Array = []
var _entry_index := 0
var _line_index := 0
var _pages: Array[String] = []
var _page_index := 0

var _panel: UiPanel
var _portrait: TextureRect
var _portrait_frame: UiPanel
var _nameplate: ColorRect
var _speaker_label: Label
var _text_label: Label
var _advance_label: Label


func _ready() -> void:
	layer = 10
	_panel = UiPanel.create(PresentationLayout.DIALOGUE_RECT.position, PresentationLayout.DIALOGUE_RECT.size, UiStyle.COMMAND)
	_panel.clip_contents = true
	add_child(_panel)

	_portrait_frame = UiPanel.create(PresentationLayout.PORTRAIT_RECT.position - Vector2(1, 1), PresentationLayout.PORTRAIT_RECT.size + Vector2(2, 2), UiStyle.NEUTRAL, false)
	_portrait_frame.visible = false
	_panel.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	PresentationLayout.texture_box(_portrait, PresentationLayout.PORTRAIT_RECT)
	_portrait.visible = false
	_panel.add_child(_portrait)
	# Speaker plate: gold spaced capitals over a short hairline rule.
	_nameplate = ColorRect.new()
	_nameplate.color = Color(UiStyle.GOLD, 0.5)
	_nameplate.position = Vector2(6, 11.5)
	_nameplate.size = Vector2(80, UiStyle.HAIR)
	_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_nameplate)

	_speaker_label = UiStyle.make_label(_panel, Rect2(7, 3, 280, 8), "", 6, UiStyle.GOLD_BRIGHT, UiStyle.MEDIUM, 1)
	_speaker_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	_text_label = UiStyle.make_label(_panel, Rect2(6, PresentationLayout.TEXT_TOP, 280, PresentationLayout.TEXT_HEIGHT), "", PresentationLayout.DIALOGUE_FONT_SIZE, UiStyle.TEXT)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_constant_override("line_spacing", PresentationLayout.DIALOGUE_LINE_GAP)

	_advance_label = UiStyle.make_label(_panel, Rect2(PresentationLayout.DIALOGUE_RECT.size.x - 12, PresentationLayout.DIALOGUE_RECT.size.y - 9, 8, 7), "Z", 5, UiStyle.GOLD, UiStyle.MEDIUM)
	_advance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pulse := create_tween().set_loops()
	pulse.tween_property(_advance_label, "modulate:a", 0.35, 0.7)
	pulse.tween_property(_advance_label, "modulate:a", 1.0, 0.7)

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
	if _entries.is_empty():
		push_error("DialogueBox: empty conversation " + key)
		return
	_entry_index = 0
	_line_index = 0
	active = true
	visible = true
	_show_current_line()


func _show_current_line() -> void:
	var entry: Dictionary = _entries[_entry_index]
	_speaker_label.text = str(entry.get("speaker", "")).to_upper()
	var lines: Array = entry.get("lines", [])
	_apply_portrait(str(entry.get("portrait", "")), str(entry.get("expression", "neutral")))
	_pages = paginate(str(lines[_line_index]), _text_label.get_theme_font("font"), PresentationLayout.DIALOGUE_FONT_SIZE, _text_label.size.x, PresentationLayout.TEXT_HEIGHT)
	_page_index = 0
	_text_label.text = _pages[0]


static func paginate(text: String, font: Font, font_size: int, width: float, height: float) -> Array[String]:
	# Measure with the actual font. Character fallback also handles long tokens.
	var pages: Array[String] = []
	var line := ""
	var page := ""
	var line_count := 0
	var gap := float(PresentationLayout.DIALOGUE_LINE_GAP)
	var capacity := maxi(1, floori((height + gap) / (font.get_height(font_size) + gap)))
	var wrapped: Array[String] = []
	for paragraph in text.split("\n", true):
		line = ""
		for word in paragraph.split(" ", false):
			var candidate := word if line.is_empty() else line + " " + word
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
				line = candidate
				continue
			if not line.is_empty():
				wrapped.append(line)
			line = ""
			for character in word:
				if not line.is_empty() and font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
					wrapped.append(line)
					line = ""
				line += character
		wrapped.append(line)
	for row in wrapped:
		if line_count == capacity:
			pages.append(page)
			page = ""
			line_count = 0
		page += ("\n" if line_count > 0 else "") + row
		line_count += 1
	pages.append(page)
	return pages


func _apply_portrait(portrait_key: String, expression := "neutral") -> void:
	CharacterPresentation.apply_portrait(_portrait, portrait_key, expression)
	var shown := _portrait.texture != null
	_portrait_frame.visible = shown
	var text_x := PresentationLayout.PORTRAIT_RECT.end.x + 6.0 if shown else 6.0
	var text_width := _panel.size.x - text_x - PresentationLayout.RIGHT_MARGIN
	_nameplate.position.x = text_x
	_nameplate.size.x = minf(text_width, UiStyle.text_width(_speaker_label.text.to_upper(), 6, UiStyle.MEDIUM, 1.0) + 10.0)
	_speaker_label.position.x = text_x
	_text_label.position.x = text_x
	_speaker_label.size.x = text_width
	_text_label.size.x = text_width


func _advance() -> void:
	if _page_index + 1 < _pages.size():
		_page_index += 1
		_text_label.text = _pages[_page_index]
		return
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
