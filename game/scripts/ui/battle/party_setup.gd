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
var _crest_art: TextureRect
var _entity_art: TextureRect

const CONTENT_TOP := 30.0
const CONTENT_BOTTOM := 154.0
const FOOTER_TOP := 158.0


func _ready() -> void:
	_encounter = GameData.get_encounter(GameState.pending_encounter)
	_slots = int(_encounter.get("player_slots", 3))
	if not bool(_encounter.get("pre_battle_positioning", true)):
		get_tree().change_scene_to_file.call_deferred(BATTLE_SCENE)
		return
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = PlaceholderPalette.BG_DARK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Roster on the left (the player's choices, so gold), encounter
	# detail on the right (what it affects, so violet) — the same accent
	# grammar the battle HUD uses.
	add_child(UiPanel.create(Vector2(8, 4), Vector2(304, 22), UiStyle.COMMAND))
	add_child(UiPanel.create(Vector2(8, CONTENT_TOP), Vector2(174, CONTENT_BOTTOM - CONTENT_TOP), UiStyle.COMMAND))
	add_child(UiPanel.create(Vector2(186, CONTENT_TOP), Vector2(126, CONTENT_BOTTOM - CONTENT_TOP), UiStyle.TARGET))
	# Instructions have their own bounded footer rather than competing with
	# the detail copy. This remains readable on the native 320x180 canvas.
	add_child(UiPanel.create(Vector2(8, FOOTER_TOP), Vector2(304, 18), UiStyle.NEUTRAL))

	_title_label = _label(Vector2(0, 10), 10, PlaceholderPalette.TEXT_WARN)
	_title_label.text = "PARTY SETUP — %s" % _encounter.get("name", "")
	# Both labels are clamped to their panel's interior; the roster's
	# Long authority names used to bleed into the detail
	# column when the label was left at full screen width.
	_rows_label = _label(Vector2(14, 34), 7, PlaceholderPalette.TEXT_MAIN)
	_rows_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rows_label.size = Vector2(162, 114)
	_rows_label.clip_text = true
	_detail_label = _label(Vector2(192, 78), 7, PlaceholderPalette.TEXT_DIM)
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_label.size = Vector2(114, 70)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.clip_text = true
	_hint_label = _label(Vector2(12, 162), 6, PlaceholderPalette.TEXT_DIM)
	_hint_label.size = Vector2(296, 10)
	_hint_label.text = "UP/DOWN SELECT   LEFT/RIGHT ROW   Z CONFIRM   X BACK"
	_portrait = TextureRect.new()
	PresentationLayout.texture_box(_portrait, Rect2(191, 35, 34, 40))
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_portrait)
	_crest_art = _make_identity_art(Vector2(230, 35))
	_entity_art = _make_identity_art(Vector2(268, 35))


func _make_identity_art(at: Vector2) -> TextureRect:
	var art := TextureRect.new()
	PresentationLayout.texture_box(art, Rect2(at, Vector2(34, 40)))
	add_child(art)
	return art


func _optional_texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _label(top_left: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = top_left
	label.size = Vector2(320 - top_left.x, 180 - top_left.y)
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
		details.append("FRONT — full melee power;")
		details.append("more exposed.")
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
