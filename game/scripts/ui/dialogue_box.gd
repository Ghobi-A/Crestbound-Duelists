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
##
## Text reveals letter by letter. Confirm (or Back) first completes the
## reveal, and the next press advances, so a line is never skipped unread.
## A conversation whose first entry sets "staging": "scene" is an authored
## story scene: StoryStage softens the location into a backdrop and stands
## the speakers up large (Kai left, the others right, facing him), and the
## panel grows into a nameplate tab over a wider serif text box. Speakers
## without large art keep their small portrait inside the panel, and
## incidental conversations keep the compact box.

signal dialogue_finished(key: String)

const PORTRAIT_PATH := "res://assets/portraits/%s/neutral.png"
const PORTRAIT_SIZE := Vector2(34, 38)
const PORTRAIT_MARGIN := Vector2(4, 3)
const TEXT_MARGIN_RIGHT := 6.0

const REVEAL_RATE := 55.0       # characters per second
const PUNCTUATION_PAUSE := 0.1  # extra seconds after . , ! ? ; : and dashes
const STORY_PANEL_RECT := Rect2(8, 126, 304, 50)
const STORY_TEXT_RECT := Rect2(10, 6, 284, 38)
const STORY_FONT_SIZE := 8
const STORY_TAB_HEIGHT := 11.0

var active := false
var staged := false
var revealing := false

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
var _advance_chevron: Control
var _stage: StoryStage
var _tab: UiPanel
var _tab_label: Label
var _reveal := 0.0
var _pause := 0.0
var _speaker_key := ""


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

	# Continue cue: a small gold chevron that bobs once the line is shown.
	# The holder is placed per layout; only the inner mark bobs.
	_advance_chevron = Control.new()
	_advance_chevron.size = Vector2(6, 6)
	_advance_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_advance_chevron)
	var mark := Control.new()
	mark.size = Vector2(6, 5)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func() -> void:
		mark.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(2.5, 3.2)]), UiStyle.GOLD_BRIGHT))
	_advance_chevron.add_child(mark)
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property(mark, "position:y", 1.2, 0.45)
	bob.tween_property(mark, "position:y", 0.0, 0.45)

	# Story staging sits under the panel; the nameplate tab rides above it.
	_stage = StoryStage.new()
	add_child(_stage)
	move_child(_stage, 0)
	_tab = UiPanel.create(Vector2.ZERO, Vector2(60, STORY_TAB_HEIGHT), UiStyle.COMMAND, false)
	_tab.visible = false
	add_child(_tab)
	_tab_label = UiStyle.make_label(_tab, Rect2(0, 1, 60, STORY_TAB_HEIGHT - 2), "", 7, UiStyle.GOLD_BRIGHT, UiStyle.DISPLAY)
	_tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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
	staged = str((_entries[0] as Dictionary).get("staging", "")) == "scene"
	_layout(staged)
	if staged:
		_stage.begin(_entries)
	_show_current_line()


func _layout(story: bool) -> void:
	## Compact box for incidental talk; the wider serif panel for a staged scene.
	var rect := STORY_PANEL_RECT if story else PresentationLayout.DIALOGUE_RECT
	_panel.position = rect.position
	_panel.size = rect.size
	_panel.queue_redraw()
	_nameplate.visible = not story
	_speaker_label.visible = not story
	_tab.visible = false
	var font_size := STORY_FONT_SIZE if story else PresentationLayout.DIALOGUE_FONT_SIZE
	_text_label.add_theme_font_override("font", UiStyle.font(UiStyle.SERIF if story else UiStyle.REGULAR))
	_text_label.add_theme_font_size_override("font_size", font_size)
	_text_label.position.y = STORY_TEXT_RECT.position.y if story else PresentationLayout.TEXT_TOP
	_text_label.size.y = STORY_TEXT_RECT.size.y if story else PresentationLayout.TEXT_HEIGHT
	_advance_chevron.position = rect.size - Vector2(10, 8)
	if not story:
		_stage.clear()


func _font_size() -> int:
	return STORY_FONT_SIZE if staged else PresentationLayout.DIALOGUE_FONT_SIZE


func _text_height() -> float:
	return STORY_TEXT_RECT.size.y if staged else PresentationLayout.TEXT_HEIGHT


func _show_current_line() -> void:
	var entry: Dictionary = _entries[_entry_index]
	_speaker_label.text = str(entry.get("speaker", "")).to_upper()
	var lines: Array = entry.get("lines", [])
	_speaker_key = str(entry.get("portrait", ""))
	var on_stage := staged and _stage.has_figure(_speaker_key)
	_apply_portrait("" if on_stage else _speaker_key, str(entry.get("expression", "neutral")))
	if staged:
		_stage.focus(_speaker_key)
		_place_tab(str(entry.get("speaker", "")))
	_pages = paginate(str(lines[_line_index]), _text_label.get_theme_font("font"), _font_size(), _text_label.size.x, _text_height())
	_page_index = 0
	_show_page(_pages[0])


func _show_page(text: String) -> void:
	_text_label.text = text
	_text_label.visible_characters = 0
	_reveal = 0.0
	_pause = 0.0
	revealing = true
	_advance_chevron.visible = false
	# Narration reads as a quieter voice than a character's line.
	_text_label.add_theme_color_override("font_color", UiStyle.TEXT if not _speaker_label.text.is_empty() else Color(UiStyle.TEXT, 0.82))


func complete_reveal() -> void:
	_text_label.visible_characters = -1
	revealing = false
	_advance_chevron.visible = true


func confirm() -> void:
	## One press of Confirm/Back: finish the line if it is still appearing,
	## otherwise move on.
	if revealing:
		complete_reveal()
	else:
		_advance()


func _process(delta: float) -> void:
	if not active or not revealing:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var total := _text_label.get_total_character_count()
	var before := _text_label.visible_characters
	_reveal += delta * REVEAL_RATE
	var shown := mini(int(_reveal), total)
	if shown > before:
		_text_label.visible_characters = shown
		# Let a clause land before the next begins.
		if shown < total and _text_label.text.substr(shown - 1, 1) in [".", ",", "!", "?", ";", ":", "—"]:
			_pause = PUNCTUATION_PAUSE
			_reveal = float(shown)
	if shown >= total:
		complete_reveal()


func _place_tab(speaker: String) -> void:
	## The nameplate tab sits over the speaker's side of the panel; narration
	## has none.
	_tab.visible = not speaker.is_empty()
	if speaker.is_empty():
		return
	var label := speaker.to_upper()
	var width := clampf(UiStyle.text_width(label, 7, UiStyle.DISPLAY, 0.0) + 14.0, 40.0, 150.0)
	_tab.size = Vector2(width, STORY_TAB_HEIGHT)
	_tab_label.size.x = width
	_tab_label.text = label
	_tab_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var x := _stage.figure_x(_speaker_key)
	var left := STORY_PANEL_RECT.position.x + 6.0
	var right := STORY_PANEL_RECT.end.x - 6.0 - width
	var at := left if x < 0.0 or x < PresentationLayout.CANVAS.x / 2.0 else right
	_tab.position = Vector2(at, STORY_PANEL_RECT.position.y - STORY_TAB_HEIGHT + 2.0)
	_tab.queue_redraw()


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
	AudioRouter.play_sfx("ui", "move", -6.0)
	if _page_index + 1 < _pages.size():
		_page_index += 1
		_show_page(_pages[_page_index])
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
	revealing = false
	_stage.clear()
	_tab.visible = false
	var finished_key := _current_key
	_current_key = ""
	dialogue_finished.emit(finished_key)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		confirm()
