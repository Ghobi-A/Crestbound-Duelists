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
var _detail_label: Label
var _position_label: Label
var _hint_label: Label
var _portrait: TextureRect
var _roster: _Roster
var _crest_art: TextureRect
var _entity_art: TextureRect

## Screen composition.
##
## Deliberately unframed. The 320x180 version enclosed the title, the
## roster and the hint in three separate boxes, because a box was the
## only grouping device a tiny canvas had. At 720p those became
## containers far larger than their content — the roster panel stood
## ~490px tall around ~180px of rows. Grouping is now done with
## position, a rule and the selection band. The one surface that remains
## is the detail card, which needs a ground for the portrait to sit on.
const MARGIN := 72.0
const PAD := 24.0
const ROSTER_X := MARGIN
const ROSTER_MEASURE := 560.0
const CONTENT_TOP := 188.0
const DETAIL_X := 720.0


class _Roster:
	extends Control
	## The party list, drawn rather than typeset into one Label.
	##
	## Per-row drawing is what allows a hierarchy: the duelist's name
	## leads and their slot and row sit beside it as a quiet tag. As one
	## space-padded string every column carried identical weight, and the
	## padding only lined up at all because the bitmap face was fixed
	## width — with a proportional serif it would not have.
	var rows: Array[Dictionary] = []
	var cursor := 0

	static func row_pitch() -> float:
		return Typography.line_height(Typography.Role.HEADING) + 20.0

	func _draw() -> void:
		var pitch := row_pitch()
		for i in rows.size():
			var row: Dictionary = rows[i]
			var top: float = float(i) * pitch + float(row.get("gap", 0.0))
			var baseline: float = top + Typography.size(Typography.Role.HEADING)
			var selected := i == cursor
			if selected:
				UiStyle.draw_selection_band(self, Rect2(0, top - 6.0, size.x, pitch),
					UiStyle.COMMAND)
			var ink: Color = PlaceholderPalette.TEXT_MAIN if selected else PlaceholderPalette.TEXT_DIM
			Typography.draw(self, Typography.Role.HEADING, Vector2(PAD, baseline),
				str(row.get("label", "")), ink, size.x - PAD * 2)
			var tag := str(row.get("tag", ""))
			if tag == "":
				continue
			# Right-aligned against the row's own measure, so the tags
			# line up down the list whatever the names are.
			var tag_width := Typography.measure(Typography.Role.CAPTION, tag).x
			Typography.draw(self, Typography.Role.CAPTION,
				Vector2(size.x - PAD - tag_width, baseline), tag,
				PlaceholderPalette.TEXT_DIM, tag_width)


class _TitleRule:
	extends Control
	## A hairline under the screen title, pinched by the Crest mark, and
	## the whole of the title's chrome. It replaces a full-width panel.
	func _draw() -> void:
		var accent := PlaceholderPalette.CREST_GOLD
		var faded := accent
		faded.a = 0.0
		var mid := size.x * 0.5
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(mid, 0),
				Vector2(mid, UiStyle.LINE), Vector2(0, UiStyle.LINE)]),
			PackedColorArray([faded, accent, accent, faded]))
		draw_polygon(
			PackedVector2Array([Vector2(mid, 0), Vector2(size.x, 0),
				Vector2(size.x, UiStyle.LINE), Vector2(mid, UiStyle.LINE)]),
			PackedColorArray([accent, faded, faded, accent]))
		UiStyle.draw_crest_mark(self, Vector2(mid, UiStyle.LINE * 0.5), UiStyle.SPACE_S, accent)


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

	_title_label = _label(Vector2(0, 56.0), Typography.Role.TITLE,
		PlaceholderPalette.CREST_GOLD_BRIGHT)
	_title_label.size = Vector2(canvas.x, Typography.line_height(Typography.Role.TITLE) * 1.3)
	_title_label.text = "PARTY SETUP — %s" % _encounter.get("name", "")
	var rule := _TitleRule.new()
	rule.position = Vector2(canvas.x * 0.5 - 160.0, 116.0)
	rule.size = Vector2(320.0, 16.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)

	_roster = _Roster.new()
	_roster.position = Vector2(ROSTER_X, CONTENT_TOP)
	_roster.size = Vector2(ROSTER_MEASURE, canvas.y - CONTENT_TOP - 140.0)
	_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_roster)

	# The one surface on this screen, sized to what it holds. The portrait
	# and the duelist's identity share a row; the position copy runs
	# beneath both at full width. Stacking everything under the portrait
	# left the card tall, half empty, and clipped its last two lines.
	var portrait_size := Vector2(176, 204)
	var identity_width := 240.0
	var detail_width := PAD + portrait_size.x + PAD + identity_width + PAD
	var line := Typography.line_height(Typography.Role.SECONDARY)
	var detail_height := PAD + portrait_size.y + PAD * 0.75 + line * 2.0 + PAD
	add_child(UiPanel.create(Vector2(DETAIL_X, CONTENT_TOP - PAD),
		Vector2(detail_width, detail_height), UiStyle.TARGET))

	_portrait = TextureRect.new()
	PresentationLayout.texture_box(_portrait, Rect2(Vector2(DETAIL_X + PAD, CONTENT_TOP), portrait_size))
	PresentationLayout.use_source_art_filter(_portrait)
	add_child(_portrait)

	var identity_x := DETAIL_X + PAD + portrait_size.x + PAD
	_detail_label = _label(Vector2(identity_x, CONTENT_TOP - 4.0), Typography.Role.SECONDARY,
		PlaceholderPalette.TEXT_DIM)
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_label.size = Vector2(identity_width, line * 3.4)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.clip_text = true

	# Crest and Entity badges sit under the identity lines, in the space
	# the portrait leaves beside it.
	var badge := Vector2(104, 104)
	var badge_y := CONTENT_TOP + line * 3.6
	_crest_art = _make_identity_art(Vector2(identity_x, badge_y), badge)
	_entity_art = _make_identity_art(Vector2(identity_x + badge.x + UiStyle.SPACE_M, badge_y), badge)

	# The front/back comparison is the decision this screen exists for, so
	# it spans the card rather than being squeezed into a column.
	_position_label = _label(
		Vector2(DETAIL_X + PAD, CONTENT_TOP + portrait_size.y + PAD * 0.65),
		Typography.Role.SECONDARY, PlaceholderPalette.TEXT_DIM)
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_position_label.size = Vector2(detail_width - PAD * 2, line * 2.4)
	_position_label.clip_text = true

	# Guidance, not a region: it sits on the screen's bottom margin with
	# nothing drawn around it.
	_hint_label = _label(Vector2(0, canvas.y - 96.0), Typography.Role.SECONDARY,
		PlaceholderPalette.TEXT_DIM)
	_hint_label.size = Vector2(canvas.x, Typography.line_height(Typography.Role.SECONDARY) * 1.4)
	_hint_label.text = "UP/DOWN SELECT      LEFT/RIGHT ROW      Z CONFIRM      X BACK"


func _make_identity_art(at: Vector2, art_size: Vector2) -> TextureRect:
	var art := TextureRect.new()
	PresentationLayout.texture_box(art, Rect2(at, art_size))
	add_child(art)
	return art


func _optional_texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _label(top_left: Vector2, role: Typography.Role, color: Color) -> Label:
	var label := Label.new()
	label.position = top_left
	label.size = PresentationLayout.CANVAS - top_left
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Typography.apply(label, role, color)
	add_child(label)
	return label


func _row_count() -> int:
	return GameState.party.size() + 1  # members + START row


func _refresh() -> void:
	var battlefield: Dictionary = _encounter.get("battlefield_effect", {})
	var rows: Array[Dictionary] = []
	for i in GameState.party.size():
		var build: Dictionary = GameState.party[i]
		var slot := "ACTIVE" if i < _slots else "RESERVE"
		var row: String = str(build.get("position", "front")).to_upper()
		rows.append({
			"label": str(build.get("name", "?")),
			"tag": "%s  ·  %s" % [slot, row],
		})
	rows.append({
		"label": "Start Battle",
		"tag": "%d DUELIST%s" % [_slots, "" if _slots == 1 else "S"],
		# Set apart from the roster it acts on: this is the screen's
		# commit, not another party member.
		"gap": UiStyle.SPACE_XL,
	})
	_roster.rows = rows
	_roster.cursor = _cursor
	_roster.queue_redraw()

	if _cursor < GameState.party.size():
		var build: Dictionary = GameState.party[_cursor]
		var class_record: Dictionary = GameData.get_class_record(build.get("class_id", ""))
		var crest: Dictionary = GameData.get_crest(build.get("crest_id", "")) if build.get("crest_id", "") else {}
		var entity: Dictionary = GameData.get_entity(build.get("entity_id", "")) if build.get("entity_id", "") else {}
		_detail_label.text = "\n".join([
			str(class_record.get("name", "?")),
			str(crest.get("name", "NO CREST")),
			str(entity.get("name", "NO ENTITY")),
		])
		# Shortened to two lines that fit the card at secondary size —
		# the previous wording measured past the box and lost its last
		# line entirely.
		_position_label.text = "FRONT — more power, more exposed.\nBACK — safer, weaker melee."
		CharacterPresentation.apply_portrait(_portrait, str(build.get("sprite_key", "")))
		_crest_art.texture = _optional_texture("res://assets/crests/%s/icon.png" % build.get("crest_id", ""))
		_entity_art.texture = _optional_texture("res://assets/entities/%s/card.png" % build.get("entity_id", ""))
	else:
		var details: Array[String] = []
		if not battlefield.is_empty():
			details.append(battlefield.get("name", ""))
			details.append(str(battlefield.get("description", "")))
		_detail_label.text = "\n".join(details)
		_position_label.text = ""
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
