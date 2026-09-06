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
const PORTRAIT_SIZE := Vector2(136, 152)
const PORTRAIT_MARGIN := Vector2(16, 12)
const TEXT_MARGIN_RIGHT := 24.0
const PAD := 24.0

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
var _speaker_label: Label
var _text_label: Label
var _advance_mark: _AdvanceChevron


class _AdvanceChevron:
	extends Control
	## The "there is more to read" prompt. A slow bob rather than a blink:
	## blinking pulls the eye away from the line being read.
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var bob := sin(_time * 3.0) * 3.0
		var w := 9.0
		var h := 7.0
		var tip := Vector2(0, bob)
		draw_colored_polygon(
			PackedVector2Array([
				tip + Vector2(-w, -h),
				tip + Vector2(w, -h),
				tip,
			]),
			PlaceholderPalette.CREST_GOLD
		)


func _ready() -> void:
	layer = 10
	_panel = UiPanel.create(PresentationLayout.DIALOGUE_RECT.position, PresentationLayout.DIALOGUE_RECT.size, UiStyle.COMMAND)
	# The portrait overhangs the panel's top edge on purpose, so the panel
	# must not clip its children. Each label clips its own text instead.
	_panel.clip_contents = false
	add_child(_panel)

	_portrait = TextureRect.new()
	PresentationLayout.texture_box(_portrait, PresentationLayout.PORTRAIT_RECT)
	# Portraits are painterly renders, not native pixel art like the rest
	# of the game, so they smooth rather than alias. The box is now very
	# nearly 1:1 with the 138x160 atlas crop.
	PresentationLayout.use_source_art_filter(_portrait)
	_portrait.visible = false
	_panel.add_child(_portrait)

	_speaker_label = Label.new()
	_speaker_label.position = Vector2(PAD, PAD * 0.4)
	_speaker_label.size = Vector2(PresentationLayout.DIALOGUE_RECT.size.x - PAD * 2,
		Typography.line_height(Typography.Role.TITLE) * 1.2)
	_speaker_label.clip_text = true
	_speaker_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Typography.apply(_speaker_label, Typography.Role.TITLE, PlaceholderPalette.CREST_GOLD_BRIGHT)
	_panel.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.position = Vector2(PAD, PresentationLayout.TEXT_TOP)
	_text_label.size = Vector2(
		PresentationLayout.DIALOGUE_RECT.size.x - PAD - PresentationLayout.RIGHT_MARGIN,
		PresentationLayout.TEXT_HEIGHT)
	_text_label.clip_text = true
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Typography.apply(_text_label, Typography.Role.BODY, PlaceholderPalette.TEXT_MAIN)
	_panel.add_child(_text_label)

	# Drawn, not typeset: the bitmap face has no triangle glyph, and a
	# U+25BC fell back to a tofu box showing its own codepoint.
	_advance_mark = _AdvanceChevron.new()
	_advance_mark.position = Vector2(
		PresentationLayout.DIALOGUE_RECT.size.x - PAD * 2.0,
		PresentationLayout.DIALOGUE_RECT.size.y - PAD * 1.6)
	_advance_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_advance_mark)

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
	_speaker_label.text = entry.get("speaker", "")
	var lines: Array = entry.get("lines", [])
	_apply_portrait(str(entry.get("portrait", "")), str(entry.get("expression", "neutral")))
	_pages = paginate(str(lines[_line_index]), Typography.font(Typography.Role.BODY),
		Typography.size(Typography.Role.BODY), _text_label.size.x, PresentationLayout.TEXT_HEIGHT)
	_page_index = 0
	_text_label.text = _pages[0]


static func paginate(text: String, font: Font, font_size: int, width: float, height: float) -> Array[String]:
	# Measure with the actual font. Character fallback also handles long tokens.
	var pages: Array[String] = []
	var line := ""
	var page := ""
	var line_count := 0
	var capacity := maxi(1, floori((height + 3.0) / (font.get_height(font_size) + 3.0)))
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
	var text_x := PresentationLayout.PORTRAIT_RECT.end.x + PAD if shown else PAD
	var text_width := _panel.size.x - text_x - PresentationLayout.RIGHT_MARGIN
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
