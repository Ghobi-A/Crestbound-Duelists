extends Node2D
## Variable-size party battle scene (1v1 / 2v2 / 3v3 / asymmetric).
##
## Round loop: the player selects one action per living party member
## (Basic / Signature / Gambit / Brace, then a target for offensive
## moves), reviews the round plan, confirms — then all committed
## player and enemy actions resolve by initiative (Brace first, then
## probabilistic speed). Cooldowns, statuses and Crest state tick at
## round end. No grid, no movement phase: positioning is decided
## before battle (front/back) and expressed through combat rules.

const OVERWORLD_SCENE := "res://scenes/overworld/greymere.tscn"
const BOOT_SCENE := "res://scenes/boot/boot.tscn"
const COURT_RETURN_TILE := Vector2i(11, 2)

enum State { INTRO, SELECT_MENU, SELECT_TARGET, PREVIEW, RESOLVING, RESULT }

var runtime: EncounterRuntime
var resolver: BattleResolver
var hud: BattleHud
var dialogue: DialogueBox
var target_selector := TargetSelector.new()

var state: State = State.INTRO
var sprites: Dictionary = {}      # BattleUnit -> DuelistSprite
var selection_order: Array = []   # living player units, selection sequence
var selection_index := 0
var planned_actions: Array = []
var pending_move: Dictionary = {}


func _ready() -> void:
	runtime = EncounterRuntime.start(GameState.pending_encounter, GameData, GameState)
	resolver = BattleResolver.new(runtime, GameData)
	_stage_units()
	_build_hud()
	_build_dialogue()
	var objective: Dictionary = GameData.get_objective(runtime.encounter.get("objective", "defeat_all"))
	hud.set_objective(objective.get("name", "Defeat all enemies"))
	hud.set_phase(str(runtime.encounter.get("name", "Battle")))
	var intro_key: String = runtime.encounter.get("intro_dialogue", "")
	if intro_key != "" and dialogue.has_key(intro_key):
		dialogue.play(intro_key)
	else:
		_start_selection()


func _stage_units() -> void:
	for unit in runtime.all_units():
		var sprite := DuelistSprite.new()
		add_child(sprite)
		sprite.configure(unit, stage_position(unit))
		sprites[unit] = sprite


func stage_position(unit: BattleUnit) -> Vector2:
	## Dynamic staging: enemies across the top, players across the
	## bottom, spread by party width, front/back rows offset toward or
	## away from the opposing side.
	var team_units: Array = runtime.player_units if unit.team == "player" else runtime.enemy_units
	var count := team_units.size()
	var x := 160.0 + (unit.slot_index - (count - 1) / 2.0) * (64.0 if count < 3 else 56.0)
	var y: float
	if unit.team == "enemy":
		y = 56.0 if unit.position == "front" else 40.0
	else:
		y = 84.0 if unit.position == "front" else 98.0
	return Vector2(x, y)


func _build_hud() -> void:
	hud = BattleHud.new()
	add_child(hud)
	hud.build_rows(runtime.player_units)


func _build_dialogue() -> void:
	dialogue = DialogueBox.new()
	var location: String = runtime.encounter.get("location", "")
	var dialogue_path := "res://data/dialogue/%s.json" % location
	if FileAccess.file_exists(dialogue_path):
		dialogue.load_file(dialogue_path)
	dialogue.dialogue_finished.connect(_on_dialogue_finished)
	add_child(dialogue)


func _on_dialogue_finished(key: String) -> void:
	if key == runtime.encounter.get("intro_dialogue", "__none__"):
		_start_selection()
	elif key == runtime.encounter.get("victory_dialogue", "__none__"):
		_leave_after_victory()
	elif key == runtime.encounter.get("defeat_dialogue", "__none__"):
		get_tree().change_scene_to_file(BOOT_SCENE)


# ── Action selection ─────────────────────────────────────────────────

func _start_selection() -> void:
	state = State.SELECT_MENU
	selection_order = runtime.living("player")
	selection_index = 0
	planned_actions = []
	for unit in runtime.player_units:
		hud.mark_planned(unit, false)
	hud.set_phase("ROUND %d — choose actions" % runtime.round_number)
	hud.set_message("")
	hud.refresh_rows()
	_open_menu_for_current()


func _current_unit() -> BattleUnit:
	return selection_order[selection_index]


func _open_menu_for_current() -> void:
	state = State.SELECT_MENU
	var unit := _current_unit()
	hud.highlight_unit(unit)
	hud.show_menu(unit)
	queue_redraw()


func _commit_action(action: Dictionary) -> void:
	planned_actions.append(action)
	hud.mark_planned(action.actor, true)
	hud.hide_menu()
	hud.hide_info()
	selection_index += 1
	if selection_index >= selection_order.size():
		_open_preview()
	else:
		_open_menu_for_current()


func _open_preview() -> void:
	state = State.PREVIEW
	hud.highlight_unit(null)
	hud.hide_menu()
	hud.hide_info()
	hud.round_preview.open(planned_actions)
	queue_redraw()


func _reopen_last_selection() -> void:
	hud.round_preview.close()
	if planned_actions.is_empty():
		_start_selection()
		return
	var last: Dictionary = planned_actions.pop_back()
	hud.mark_planned(last.actor, false)
	selection_index = maxi(0, selection_index - 1)
	_open_menu_for_current()


func _unhandled_input(event: InputEvent) -> void:
	if dialogue != null and dialogue.active:
		return
	if not event.is_pressed() or event.is_echo():
		return
	match state:
		State.SELECT_MENU:
			_menu_input(event)
		State.SELECT_TARGET:
			_target_input(event)
		State.PREVIEW:
			_preview_input(event)


func _menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		hud.action_menu.move_cursor(-1)
	elif event.is_action_pressed("move_down"):
		hud.action_menu.move_cursor(1)
	elif event.is_action_pressed("cancel"):
		if selection_index > 0:
			_reopen_last_selection()
	elif event.is_action_pressed("interact"):
		var entry := hud.action_menu.current_entry()
		if not entry.enabled:
			return
		var unit := _current_unit()
		if entry.kind == "brace":
			_commit_action({"actor": unit, "kind": "brace", "move": {}, "target": null})
			return
		pending_move = entry.move
		if target_selector.open(unit, runtime):
			state = State.SELECT_TARGET
			_refresh_target_info()
			queue_redraw()


func _target_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		target_selector.cycle(-1)
		_refresh_target_info()
		queue_redraw()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		target_selector.cycle(1)
		_refresh_target_info()
		queue_redraw()
	elif event.is_action_pressed("cancel"):
		hud.hide_info()
		_open_menu_for_current()
	elif event.is_action_pressed("interact"):
		var unit := _current_unit()
		_commit_action({
			"actor": unit, "kind": "move",
			"move": pending_move, "target": target_selector.current(),
		})
		queue_redraw()


func _refresh_target_info() -> void:
	hud.show_info(target_selector.estimate_text(_current_unit(), pending_move, resolver))


func _preview_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		hud.round_preview.toggle_cursor()
	elif event.is_action_pressed("cancel"):
		_reopen_last_selection()
	elif event.is_action_pressed("interact"):
		if hud.round_preview.confirmed():
			hud.round_preview.close()
			_resolve_round()
		else:
			_reopen_last_selection()


# ── Round resolution ─────────────────────────────────────────────────

func _resolve_round() -> void:
	state = State.RESOLVING
	hud.set_phase("ROUND %d — resolution" % runtime.round_number)
	hud.highlight_unit(null)
	queue_redraw()

	var all_actions := planned_actions.duplicate()
	for enemy in runtime.living("enemy"):
		all_actions.append(EnemyAI.choose_action(enemy, resolver, runtime))

	var ordered := resolver.order_actions(all_actions)
	for action in ordered:
		if runtime.victory() or runtime.defeat():
			break
		if not action.actor.is_alive():
			continue
		var events := resolver.execute(action)
		await _play_events(action, events)
		hud.refresh_rows()
		await get_tree().create_timer(0.3).timeout

	resolver.end_round()
	_after_round_tick()
	hud.refresh_rows()
	for sprite in sprites.values():
		sprite.refresh()

	if runtime.victory():
		_finish(true)
	elif runtime.defeat():
		_finish(false)
	else:
		_start_selection()


func _after_round_tick() -> void:
	## Hook for round-end systems (Crest/Resonance runtime attaches in
	## a later milestone).
	pass


func _play_events(action: Dictionary, events: Array) -> void:
	var actor: BattleUnit = action.actor
	for event in events:
		match event.type:
			"action_start":
				if action.kind == "move":
					hud.set_message("%s: %s" % [actor.display_name, event.label])
					sprites[actor].play("attack")
					await get_tree().create_timer(0.25).timeout
			"brace":
				hud.set_message("%s braces." % actor.display_name)
				sprites[actor].play("brace")
				await get_tree().create_timer(0.2).timeout
			"blocked":
				hud.set_message("%s: %s is blocked by Hex!" % [actor.display_name, event.move_name])
				_popup(sprites[actor].home_position, "HEX", PlaceholderPalette.TILE_CREST_NODE.lightened(0.4))
				await get_tree().create_timer(0.35).timeout
			"retarget":
				hud.set_message("%s turns to %s!" % [actor.display_name, event.target.display_name])
			"miss":
				_popup(sprites[event.target].home_position, "MISS", PlaceholderPalette.TEXT_DIM)
				hud.set_message("%s: %s missed!" % [actor.display_name, event.move_name])
				await get_tree().create_timer(0.3).timeout
			"intercept":
				hud.set_message("%s shields %s!" % [event.protector.display_name, event.original_target.display_name])
				_popup(sprites[event.protector].home_position, "GUARD", PlaceholderPalette.PANEL_BORDER)
				await get_tree().create_timer(0.3).timeout
			"damage":
				var target: BattleUnit = event.target
				_popup(sprites[target].home_position, str(event.amount), Color.WHITE)
				sprites[target].play("defeat" if event.ko else "hit")
				hud.set_message("%s takes %d." % [target.display_name, event.amount])
				await get_tree().create_timer(0.3).timeout
				if event.ko:
					hud.set_message("%s falls!" % target.display_name)
					await get_tree().create_timer(0.3).timeout
			"counter":
				var victim: BattleUnit = event.target
				_popup(sprites[victim].home_position, str(event.amount), Color("7ec8ff"))
				sprites[victim].play("defeat" if event.ko else "hit")
				hud.set_message("%s counters for %d!" % [event.actor.display_name, event.amount])
				await get_tree().create_timer(0.3).timeout
			"lifesteal":
				_popup(sprites[event.actor].home_position, "+%d" % event.amount, Color("57c26b"))
			"stat_mod":
				var label := "%s%+d" % [str(event.stat).to_upper(), event.amount]
				var color := Color("e05555") if event.amount < 0 else Color("57c26b")
				_popup(sprites[event.target].home_position + Vector2(0, -8), label, color)
			"status":
				_popup(sprites[event.target].home_position + Vector2(0, -8), str(event.status).to_upper(), PlaceholderPalette.TILE_CREST_NODE.lightened(0.4))
			"crest":
				pass  # consumed by the Crest runtime milestone
		for sprite in sprites.values():
			sprite.refresh()


func _popup(world_position: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = world_position + Vector2(-10, -18)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.z_index = 20
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 10, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tween.tween_callback(label.queue_free)


# ── Battle end ───────────────────────────────────────────────────────

func _finish(player_won: bool) -> void:
	state = State.RESULT
	hud.hide_menu()
	hud.hide_info()
	if player_won:
		hud.set_phase("VICTORY")
		hud.set_message("The enemy is defeated.")
		var key: String = runtime.encounter.get("victory_dialogue", "")
		if key != "" and dialogue.has_key(key):
			dialogue.play(key)
		else:
			_leave_after_victory()
	else:
		hud.set_phase("DEFEAT")
		hud.set_message("The party is overwhelmed...")
		var key: String = runtime.encounter.get("defeat_dialogue", "")
		if key != "" and dialogue.has_key(key):
			dialogue.play(key)
		else:
			get_tree().change_scene_to_file(BOOT_SCENE)


func _leave_after_victory() -> void:
	var encounter_id: String = runtime.encounter.get("id", GameState.pending_encounter)
	GameState.set_flag("%s_won" % encounter_id)
	if GameState.pending_encounter == "hollow_court_battle":
		GameState.set_flag("hollow_court_cleared")
		GameState.set_flag("post_battle_scene_pending")
		GameState.player_tile = COURT_RETURN_TILE
	SaveManager.save_game()
	get_tree().change_scene_to_file(OVERWORLD_SCENE)


# ── Overlay drawing (selection + target markers) ─────────────────────

func _draw() -> void:
	if state == State.SELECT_MENU or state == State.SELECT_TARGET:
		if selection_index < selection_order.size():
			var actor := _current_unit()
			var home: Vector2 = sprites[actor].home_position
			draw_rect(Rect2(home + Vector2(-10, -16), Vector2(20, 30)), PlaceholderPalette.OVERLAY_SELECTED, false, 1.0)
	if state == State.SELECT_TARGET:
		var target := target_selector.current()
		if target != null:
			var home: Vector2 = sprites[target].home_position
			draw_rect(Rect2(home + Vector2(-10, -16), Vector2(20, 30)), PlaceholderPalette.OVERLAY_CURSOR, false, 1.0)
			draw_rect(Rect2(home + Vector2(-2, -22), Vector2(4, 4)), PlaceholderPalette.TEXT_DANGER)
