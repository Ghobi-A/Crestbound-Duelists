extends Control
## Pre-battle party setup: review the party, choose front/back
## positions, reorder members (the first N fill the encounter's active
## slots), and start the battle. There is no in-battle movement — this
## screen is where positioning happens.
##
## Controls: Up/Down move the cursor. Left/Right toggle front/back.
## Interact on a member swaps it upward (reordering the active slots);
## interact on START begins the battle. Cancel returns to Greymere.

const BATTLE_SCENE := "res://scenes/battle/party_battle.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/greymere.tscn"

var _encounter: Dictionary = {}
var _slots := 3
var _cursor := 0

var _title_label: Label
var _rows_label: Label
var _detail_label: Label
var _hint_label: Label
var _portrait: TextureRect
var _band: _RosterBand
var _crest_art: TextureRect
var _entity_art: TextureRect

## Screen bands. Derived from the canvas so the three panels stay
## aligned to one grid rather than to hand-placed offsets.
const MARGIN := 32.0
const PAD := 24.0
const TITLE_HEIGHT := 88.0
const FOOTER_HEIGHT := 48.0
const CONTENT_TOP := MARGIN + TITLE_HEIGHT + 16.0                       # 136
const FOOTER_TOP := PresentationLayout.CANVAS.y - MARGIN - FOOTER_HEIGHT # 640
const CONTENT_BOTTOM := FOOTER_TOP - 16.0                                # 624
## The roster takes the wider share; encounter detail sits beside it.
const ROSTER_WIDTH := 696.0
## Must match the line advance the roster Label uses, or the selection
## band drifts away from the row it is meant to be behind.
const ROW_PITCH := Typography.BODY + 6.0


class _RosterBand:
	extends Control
	## Highlight behind the selected roster row. The roster is one
	## multi-line Label, so the band is drawn separately underneath it
	## rather than by splitting the roster into per-row controls.
	var row := 0
	var row_pitch := 30.0
	var visible_band := true

	func _draw() -> void:
		if not visible_band:
			return
		UiStyle.draw_selection_band(self,
			Rect2(0, row * row_pitch, size.x, row_pitch), UiStyle.COMMAND)


func _ready() -> void:
	_encounter = GameData.get_encounter(GameState.pending_encounter)
	_slots = int(_encounter.get("player_slots", 3))
	if not bool(_encounter.get("pre_battle_positioning", true)):
		get_tree().change_scene_to_file.call_deferred(BATTLE_SCENE)
		return
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var canvas := PresentationLayout.CANVAS
	var background := ColorRect.new()
	background.color = PlaceholderPalette.BG_DARK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var content_height := CONTENT_BOTTOM - CONTENT_TOP
	var detail_x := MARGIN + ROSTER_WIDTH + 16.0
	var detail_width := canvas.x - MARGIN - detail_x
	# Roster on the left (the player's choices, so gold), encounter
	# detail on the right (what it affects, so violet) — the same accent
	# grammar the battle HUD uses.
	add_child(UiPanel.create(Vector2(MARGIN, MARGIN), Vector2(canvas.x - MARGIN * 2, TITLE_HEIGHT), UiStyle.COMMAND))
	add_child(UiPanel.create(Vector2(MARGIN, CONTENT_TOP), Vector2(ROSTER_WIDTH, content_height), UiStyle.COMMAND))
	add_child(UiPanel.create(Vector2(detail_x, CONTENT_TOP), Vector2(detail_width, content_height), UiStyle.TARGET))
	# Instructions have their own bounded footer rather than competing
	# with the detail copy.
	add_child(UiPanel.create(Vector2(MARGIN, FOOTER_TOP), Vector2(canvas.x - MARGIN * 2, FOOTER_HEIGHT), UiStyle.NEUTRAL))

	_title_label = _label(Vector2(0, MARGIN + PAD), Typography.HEADING, PlaceholderPalette.TEXT_WARN)
	_title_label.size = Vector2(canvas.x, TITLE_HEIGHT)
	_title_label.text = "PARTY SETUP — %s" % _encounter.get("name", "")

	# Both labels are clamped to their panel's interior so long authority
	# names cannot bleed into the detail column.
	# The band is added before the label so it renders behind the text.
	_band = _RosterBand.new()
	_band.position = Vector2(MARGIN + UiStyle.SPACE_S, CONTENT_TOP + PAD)
	_band.size = Vector2(ROSTER_WIDTH - UiStyle.SPACE_S * 2, content_height - PAD * 2)
	_band.row_pitch = ROW_PITCH
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)

	_rows_label = _label(Vector2(MARGIN + PAD, CONTENT_TOP + PAD), UiStyle.FONT_SIZE, PlaceholderPalette.TEXT_MAIN)
	_rows_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rows_label.size = Vector2(ROSTER_WIDTH - PAD * 2, content_height - PAD * 2)
	_rows_label.clip_text = true

	# Identity art sits in a row across the top of the detail panel; the
	# copy runs beneath it. The portrait box is larger than its 138x160
	# atlas crop's short side, so the crop is shown at close to authored
	# size instead of the 34x40 thumbnail the old canvas allowed.
	var art_top := CONTENT_TOP + PAD
	var portrait_size := Vector2(172, 200)
	_portrait = TextureRect.new()
	PresentationLayout.texture_box(_portrait, Rect2(Vector2(detail_x + PAD, art_top), portrait_size))
	PresentationLayout.use_source_art_filter(_portrait)
	add_child(_portrait)
	var badge_size := Vector2(120, 140)
	var badge_x := detail_x + PAD + portrait_size.x + PAD
	_crest_art = _make_identity_art(Vector2(badge_x, art_top), badge_size)
	_entity_art = _make_identity_art(Vector2(badge_x + badge_size.x + PAD * 0.6, art_top), badge_size)

	var detail_top := art_top + portrait_size.y + PAD
	_detail_label = _label(Vector2(detail_x + PAD, detail_top), UiStyle.FONT_SIZE, PlaceholderPalette.TEXT_DIM)
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_label.size = Vector2(detail_width - PAD * 2, CONTENT_BOTTOM - detail_top - PAD)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.clip_text = true

	_hint_label = _label(Vector2(0, FOOTER_TOP + PAD * 0.5), UiStyle.FONT_SIZE, PlaceholderPalette.TEXT_DIM)
	_hint_label.size = Vector2(canvas.x, FOOTER_HEIGHT)
	# The full wording fits again: at body size this measures 963 of the
	# 1168px footer interior, where the 320x180 canvas could not fit it
	# even with the text shrunk below the font's native size.
	_hint_label.text = "UP/DOWN SELECT   LEFT/RIGHT ROW   Z CONFIRM   X BACK"


func _make_identity_art(at: Vector2, art_size: Vector2) -> TextureRect:
	var art := TextureRect.new()
	PresentationLayout.texture_box(art, Rect2(at, art_size))
	add_child(art)
	return art


func _optional_texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _label(top_left: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = top_left
	label.size = PresentationLayout.CANVAS - top_left
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _row_count() -> int:
	return GameState.party.size() + 1  # members + START row


func _refresh() -> void:
	var lines: Array[String] = []
	var battlefield: Dictionary = _encounter.get("battlefield_effect", {})
	for i in GameState.party.size():
		var build: Dictionary = GameState.party[i]
		var cursor := "> " if _cursor == i else "  "
		var active := "ACTIVE " if i < _slots else "RESERVE"
		var row: String = str(build.get("position", "front")).to_upper()
		lines.append("%s%-7s %-5s %s" % [cursor, active, row, build.get("name", "?")])
	lines.append("")
	var start_cursor := "> " if _cursor == GameState.party.size() else "  "
	lines.append(start_cursor + "START BATTLE  (%d Duelist%s)" % [_slots, "" if _slots == 1 else "s"])
	_rows_label.text = "\n".join(lines)
	if _band != null:
		# The roster prints a blank line before START, so the START row is
		# one line further down than its cursor index.
		_band.row = _cursor if _cursor < GameState.party.size() else _cursor + 1
		_band.queue_redraw()

	if _cursor < GameState.party.size():
		var build: Dictionary = GameState.party[_cursor]
		var class_record: Dictionary = GameData.get_class_record(build.get("class_id", ""))
		var crest: Dictionary = GameData.get_crest(build.get("crest_id", "")) if build.get("crest_id", "") else {}
		var entity: Dictionary = GameData.get_entity(build.get("entity_id", "")) if build.get("entity_id", "") else {}
		var details: Array[String] = []
		details.append(class_record.get("name", "?"))
		details.append(crest.get("name", "NO CREST"))
		details.append(entity.get("name", "NO ENTITY"))
		details.append("")
		# Both rows are described again. The 320x180 detail box held six
		# lines total and four were already spent, so it could only
		# afford the selected row; this one has room for the comparison
		# the player is actually making.
		details.append("FRONT — full melee power; more exposed.")
		details.append("BACK — safer; weaker melee.")
		_detail_label.text = "\n".join(details)
		CharacterPresentation.apply_portrait(_portrait, str(build.get("sprite_key", "")))
		_crest_art.texture = _optional_texture("res://assets/crests/%s/icon.png" % build.get("crest_id", ""))
		_entity_art.texture = _optional_texture("res://assets/entities/%s/card.png" % build.get("entity_id", ""))
	else:
		var details: Array[String] = []
		if not battlefield.is_empty():
			details.append(battlefield.get("name", ""))
			details.append(str(battlefield.get("description", "")))
		_detail_label.text = "\n".join(details)
		_portrait.texture = null
		_crest_art.texture = null
		_entity_art.texture = null


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("move_up"):
		_cursor = wrapi(_cursor - 1, 0, _row_count())
		AudioRouter.play_sfx("ui", "move")
	elif event.is_action_pressed("move_down"):
		_cursor = wrapi(_cursor + 1, 0, _row_count())
		AudioRouter.play_sfx("ui", "move")
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		if _cursor < GameState.party.size():
			var build: Dictionary = GameState.party[_cursor]
			build["position"] = "back" if build.get("position", "front") == "front" else "front"
	elif event.is_action_pressed("interact"):
		AudioRouter.play_sfx("ui", "confirm")
		if _cursor == GameState.party.size():
			SaveManager.save_game()
			SceneTransition.change_scene(BATTLE_SCENE, "spectral")
			return
		elif _cursor > 0:
			# Swap upward to reorder which members fill the active slots.
			var member: Dictionary = GameState.party[_cursor]
			GameState.party[_cursor] = GameState.party[_cursor - 1]
			GameState.party[_cursor - 1] = member
			_cursor -= 1
	elif event.is_action_pressed("cancel"):
		AudioRouter.play_sfx("ui", "cancel")
		SceneTransition.change_scene(OVERWORLD_SCENE)
		return
	_refresh()
