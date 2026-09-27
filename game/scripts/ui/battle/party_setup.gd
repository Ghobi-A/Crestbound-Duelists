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
var _figure: TextureRect
var _identity_label: Label
var _roster: Control
const CARD_HEIGHT := 31.0
const CARD_PITCH := 34.0
const VISIBLE_CARDS := 3

const CONTENT_TOP := 26.0
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
	var scenery := TextureRect.new()
	PresentationLayout.texture_box(scenery, Rect2(0, 0, 320, 180))
	scenery.texture = load("res://assets/rework/hollow_court.png")
	scenery.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scenery.modulate = Color(0.22, 0.25, 0.33)
	add_child(scenery)

	# Roster on the left (the player's choices, so gold), encounter
	# detail on the right (what it affects, so violet) — the same accent
	# grammar the battle HUD uses.
	add_child(UiDecor.create("fade_left", Rect2(0, 0, 320, 16)))
	_title_label = UiStyle.make_label(self, Rect2(0, 4, 320, 9), "", 6, UiStyle.GOLD_BRIGHT, UiStyle.MEDIUM, 1)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "PARTY  ·  %s" % str(_encounter.get("name", "")).trim_prefix("The ").to_upper()
	add_child(UiDecor.create("rule", Rect2(110, 14, 100, 4)))
	add_child(UiPanel.create(Vector2(8, CONTENT_TOP), Vector2(174, CONTENT_BOTTOM - CONTENT_TOP), UiStyle.COMMAND))
	add_child(UiPanel.create(Vector2(186, CONTENT_TOP), Vector2(126, CONTENT_BOTTOM - CONTENT_TOP), UiStyle.TARGET))
	_rows_label = UiStyle.make_label(self, Rect2(14, 34, 162, 114), "", UiStyle.FONT_SIZE, UiStyle.TEXT)
	_rows_label.visible = false
	_roster = Control.new()
	add_child(_roster)
	_detail_label = UiStyle.make_label(self, Rect2(192, 80, 62, 70), "", UiStyle.FONT_SIZE, UiStyle.TEXT_DIM)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_constant_override("line_spacing", 1)
	# Instructions sit on the screen's footer rule rather than in a box.
	add_child(UiDecor.create("rule", Rect2(20, FOOTER_TOP + 2, 280, 4), UiStyle.NEUTRAL))
	_hint_label = UiStyle.make_label(self, Rect2(8, FOOTER_TOP + 8, 304, 8), "UP/DOWN SELECT   ·   LEFT/RIGHT ROW   ·   Z CONFIRM   ·   X BACK", UiStyle.FONT_SIZE, UiStyle.TEXT_FAINT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait = TextureRect.new()
	PresentationLayout.texture_box(_portrait, Rect2(192, 33, 34, 40))
	add_child(_portrait)
	_identity_label = UiStyle.make_label(self, Rect2(231, 35, 76, 36), "", 6, UiStyle.GOLD_BRIGHT, UiStyle.MEDIUM)
	# Full battle figure of the focused Duelist, from the same registered
	# combat art the battle uses (never a substitute character).
	_figure = TextureRect.new()
	PresentationLayout.texture_box(_figure, Rect2(252, 76, 56, 76))
	add_child(_figure)
	_identity_label.add_theme_constant_override("line_spacing", 2)


func _row_count() -> int:
	return GameState.party.size() + 1  # members + START row


func _refresh() -> void:
	_refresh_roster()
	var lines: Array[String] = []
	var battlefield: Dictionary = _encounter.get("battlefield_effect", {})
	for i in GameState.party.size():
		var build: Dictionary = GameState.party[i]
		var cursor := "> " if _cursor == i else "  "
		# Status is abbreviated to three characters so a full row reads
		# within the roster panel at native font size; the previous
		# "ACTIVE "/"RESERVE" padding only fit by shrinking the font.
		var active := "ACT" if i < _slots else "RES"
		var row: String = str(build.get("position", "front")).to_upper()
		lines.append("%s%s %-5s %s" % [cursor, active, row, build.get("name", "?")])
	lines.append("")
	var start_cursor := "> " if _cursor == GameState.party.size() else "  "
	lines.append(start_cursor + "START BATTLE (%d)" % _slots)
	_rows_label.text = "\n".join(lines)

	if _cursor < GameState.party.size():
		var build: Dictionary = GameState.party[_cursor]
		var class_record: Dictionary = GameData.get_class_record(build.get("class_id", ""))
		var crest: Dictionary = GameData.get_crest(build.get("crest_id", "")) if build.get("crest_id", "") else {}
		var entity: Dictionary = GameData.get_entity(build.get("entity_id", "")) if build.get("entity_id", "") else {}
		var details: Array[String] = []
		_identity_label.text = "%s\n%s" % [str(class_record.get("name", "?")).to_upper(), str(crest.get("name", "No Crest"))]
		details.append("BOND: %s" % str(entity.get("name", "None")))
		var full_hp := int(class_record.get("base_stats", {}).get("hp", 1))
		details.append("HP: %d/%d" % [int(build.get("current_hp", full_hp)), full_hp])
		details.append("")
		# Two lines is the whole budget left in this box at native font
		# size: 70px holds six 9px lines at the theme's 3px spacing, and
		# class/crest/entity/spacer already take four. So describe only
		# the row this duelist is actually in — LEFT/RIGHT swaps it and
		# the copy follows, which is the feedback that matters here.
		# Explaining both rows at once clipped the second one silently.
		if str(build.get("position", "front")) == "front":
			details.append("FRONT ROW: hits hard, more exposed.")
		else:
			details.append("BACK ROW: safer, but weaker melee.")
		_detail_label.text = "\n".join(details)
		CharacterPresentation.apply_portrait(_portrait, str(build.get("sprite_key", "")))
		_show_figure(str(build.get("sprite_key", "")))
	else:
		_figure.visible = false
		var details: Array[String] = []
		if not battlefield.is_empty():
			details.append(battlefield.get("name", ""))
			details.append(str(battlefield.get("description", "")))
		_detail_label.text = "\n".join(details)
		_identity_label.text = "FORMATION\n%d ACTIVE" % _slots
		_portrait.texture = null


func _show_figure(sprite_key: String) -> void:
	var record := CharacterPresentation.record_for(sprite_key)
	_figure.visible = not record.is_empty() and record.has("battle_rect")
	if not _figure.visible:
		return
	var crop := AtlasTexture.new()
	crop.atlas = CharacterPresentation.atlas(record)
	crop.region = CharacterPresentation.rect(record.battle_rect)
	crop.filter_clip = true
	_figure.texture = crop
	_figure.material = CharacterPresentation.key_material(record)


func _refresh_roster() -> void:
	for child in _roster.get_children():
		_roster.remove_child(child)
		child.queue_free()
	_roster.add_child(UiDecor.create("frame", Rect2(191, 32, 36, 42)))
	# Scroll through any party size without changing active-slot selection.
	var first := maxi(0, mini(_cursor, GameState.party.size() - 1) - VISIBLE_CARDS + 1)
	for i in range(first, mini(first + VISIBLE_CARDS, GameState.party.size())):
		var build: Dictionary = GameState.party[i]
		var selected := i == _cursor
		var card := UiPanel.create(Vector2(14, 31 + (i - first) * CARD_PITCH), Vector2(162, CARD_HEIGHT), UiStyle.COMMAND if selected else UiStyle.NEUTRAL, selected)
		_roster.add_child(card)
		card.add_child(UiDecor.create("frame" if not selected else "frame_active", Rect2(3, 3, 22, 25)))
		var portrait := TextureRect.new()
		PresentationLayout.texture_box(portrait, Rect2(3.75, 3.75, 20.5, 23.5))
		card.add_child(portrait)
		CharacterPresentation.apply_portrait(portrait, str(build.get("sprite_key", "")))
		var name_label := UiStyle.make_label(card, Rect2(30, 5, 128, 8), str(build.get("name", "?")).to_upper(), 6,
			UiStyle.GOLD_BRIGHT if selected else UiStyle.TEXT, UiStyle.MEDIUM)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var active := i < _slots
		var row := str(build.get("position", "front")).to_upper()
		UiStyle.make_label(card, Rect2(30, 17, 60, 7), "ACTIVE" if active else "RESERVE", UiStyle.FONT_SIZE,
			UiStyle.TEXT_DIM if active else UiStyle.TEXT_FAINT)
		var row_label := UiStyle.make_label(card, Rect2(96, 17, 60, 7), row + " ROW", UiStyle.FONT_SIZE,
			UiStyle.GOLD if row == "FRONT" else PlaceholderPalette.SPECTRAL_VIOLET, UiStyle.MEDIUM)
		row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var begin_selected := _cursor == GameState.party.size()
	var start_rect := Rect2(22, 135, 146, 11)
	if begin_selected:
		_roster.add_child(UiDecor.create("selection", start_rect))
	else:
		_roster.add_child(UiDecor.create("frame", start_rect))
	var start := UiStyle.make_label(_roster, start_rect, "BEGIN ENCOUNTER", 6,
		UiStyle.GOLD_BRIGHT if begin_selected else UiStyle.TEXT_DIM, UiStyle.MEDIUM, 1)
	start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


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
