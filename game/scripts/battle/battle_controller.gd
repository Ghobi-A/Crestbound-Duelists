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
const QUICK_BATTLE_SCENE := "res://scenes/ui/quick_battle.tscn"
const BATTLE_SCENE := "res://scenes/battle/party_battle.tscn"

## Where the floating party cards begin (battle_hud.gd); combatants stand
## above it. The background itself covers the whole canvas.
const BACKGROUND_HEIGHT := PresentationLayout.BATTLE_HEIGHT

## Formation staging. Two clear halves rather than a shared diagonal, so
## the sides read as opposing at a glance; front/back use one shared
## depth convention for both teams — front is always closer to the
## camera (larger Y) — so the read is consistent instead of mirrored.
const PLAYER_CENTER_X := PresentationLayout.PLAYER_CENTER_X
const ENEMY_CENTER_X := PresentationLayout.ENEMY_CENTER_X
const FRONT_Y := PresentationLayout.FRONT_Y
const BACK_Y := PresentationLayout.BACK_Y
const ONBOARDING_FLAG := "battle_onboarding_seen"
const ONBOARDING_TITLE := "BATTLE BASICS"
const ONBOARDING_BODY := "Choose each Duelist's action and target.\nBrace acts first and reduces incoming damage.\nBuild Resonance to awaken your Crest."

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
var pending_item := ""          # item chosen from the bag, awaiting a target
var menu_mode := "commands"     # "commands" | "items"
var stage: Node2D                 # background + unit sprites (shakeable)
var onboarding: OnboardingPanel
var presentation: BattlePresentation
var result_presentation: ResultPresentation


func _ready() -> void:
	runtime = EncounterRuntime.start(GameState.pending_encounter, GameData, GameState)
	GameState.snapshot_for_retry()
	resolver = BattleResolver.new(runtime, GameData)
	stage = BattleStage.new()
	add_child(stage)
	_stage_background()
	_stage_units()
	_build_hud()
	presentation = BattlePresentation.new()
	add_child(presentation)
	presentation.configure(stage, hud, sprites)
	presentation.summoned.connect(_on_summoned)
	# Bosses name their own theme; a theme not yet delivered falls back to the battle track.
	var theme := str(runtime.encounter.get("music", "battle"))
	AudioRouter.play_music(theme if AudioRouter.has_cue("music", theme) else "battle")
	AudioRouter.stop_ambience()
	_build_dialogue()
	_build_onboarding()
	_show_objective()
	hud.set_title(str(runtime.encounter.get("name", "Battle")).trim_prefix("The "))
	hud.set_phase("ROUND %d" % runtime.round_number)
	hud.set_footer_note(str(runtime.encounter.get("battlefield_effect", {}).get("name", "")))
	if onboarding.active:
		return
	_start_intro()


func _build_onboarding() -> void:
	onboarding = OnboardingPanel.new()
	add_child(onboarding)
	if GameState.has_flag(ONBOARDING_FLAG):
		return
	onboarding.dismissed.connect(_on_onboarding_dismissed)
	onboarding.show_panel(ONBOARDING_TITLE, ONBOARDING_BODY)


func _on_onboarding_dismissed() -> void:
	GameState.set_flag(ONBOARDING_FLAG)
	_start_intro()


func _start_intro() -> void:
	var intro_key: String = runtime.encounter.get("intro_dialogue", "")
	if intro_key != "" and dialogue.has_key(intro_key):
		dialogue.play(intro_key)
	else:
		_start_selection()


func _stage_background() -> void:
	(stage as BattleStage).build_background(str(runtime.encounter.get("location", "")))


func _stage_units() -> void:
	for unit in runtime.all_units():
		var count := runtime.player_units.size() if unit.team == "player" else runtime.enemy_units.size()
		var opposing := runtime.enemy_units.size() if unit.team == "player" else runtime.player_units.size()
		sprites[unit] = (stage as BattleStage).add_combatant(unit, count, opposing)


func stage_position(unit: BattleUnit) -> Vector2:
	var count := runtime.player_units.size() if unit.team == "player" else runtime.enemy_units.size()
	var opposing := runtime.enemy_units.size() if unit.team == "player" else runtime.player_units.size()
	return PresentationLayout.stage_position(unit.team, unit.slot_index, count, unit.position, opposing)


func _build_hud() -> void:
	hud = BattleHud.new()
	add_child(hud)
	hud.build_rows(runtime.player_units)
	hud.build_turn_rail(runtime.all_units())


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
		_leave_after_defeat()


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
	hud.set_turn_order(resolver.projected_order(runtime.all_units()))
	hud.refresh_rows()
	_open_menu_for_current()


func _current_unit() -> BattleUnit:
	return selection_order[selection_index]


func _open_menu_for_current() -> void:
	state = State.SELECT_MENU
	_clear_all_highlights()
	var unit := _current_unit()
	hud.highlight_unit(unit)
	menu_mode = "commands"
	pending_item = ""
	hud.show_menu(unit, runtime.can_flee(), available_inventory())
	if sprites.has(unit):
		sprites[unit].set_highlighted("selected")
	queue_redraw()


# ── Target highlighting (presentation only; target_selector.gd,
# battle_resolver.gd, battle_unit.gd and encounter_runtime.gd are never
# touched by any of this) ─────────────────────────────────────────────

func _clear_all_highlights() -> void:
	for u in sprites:
		sprites[u].clear_highlight()
	hud.highlight_enemy(null)
	_clear_target_dim()


func _clear_target_dim() -> void:
	for u in sprites:
		sprites[u].modulate = Color.WHITE


func _clear_target_side() -> void:
	for u in target_selector.targets:
		if sprites.has(u):
			sprites[u].clear_highlight()
	_clear_target_dim()
	hud.highlight_enemy(null)


func _refresh_target_highlights() -> void:
	var current := target_selector.current()
	hud.highlight_enemy(current)
	for u in target_selector.targets:
		if sprites.has(u):
			sprites[u].set_highlighted("target" if u == current else "")
	_apply_target_dim()


func _apply_target_dim() -> void:
	var current := target_selector.current()
	for u in target_selector.targets:
		if sprites.has(u):
			sprites[u].modulate = Color.WHITE if u == current else Color(0.55, 0.55, 0.65)


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
	_clear_all_highlights()
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
	if onboarding != null and onboarding.active:
		return
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
		AudioRouter.play_sfx("ui", "move")
	elif event.is_action_pressed("move_down"):
		hud.action_menu.move_cursor(1)
		AudioRouter.play_sfx("ui", "move")
	elif event.is_action_pressed("cancel"):
		if menu_mode == "items":
			AudioRouter.play_sfx("ui", "cancel")
			_open_menu_for_current()
		elif selection_index > 0:
			AudioRouter.play_sfx("ui", "cancel")
			_reopen_last_selection()
	elif event.is_action_pressed("interact"):
		var entry := hud.action_menu.current_entry()
		if not entry.enabled:
			AudioRouter.play_sfx("ui", "denied")
			hud.action_menu.refuse()
			return
		AudioRouter.play_sfx("ui", "confirm")
		if entry.kind == "flee":
			_try_flee()
			return
		var unit := _current_unit()
		if entry.kind == "brace":
			_commit_action({"actor": unit, "kind": "brace", "move": {}, "target": null})
			return
		if entry.kind == "awaken":
			_commit_action({"actor": unit, "kind": "awaken", "move": {}, "target": null})
			return
		if entry.kind == "items":
			menu_mode = "items"
			hud.action_menu.build_items(unit, available_inventory())
			return
		if entry.kind == "back":
			_open_menu_for_current()
			return
		if entry.kind == "item":
			pending_item = str(entry.item_id)
			pending_move = {}
			var revive := str(GameData.get_item(pending_item).get("battle_effect", {}).get("type", "")) == "revive"
			if target_selector.open_allies(unit, runtime, revive):
				state = State.SELECT_TARGET
				_refresh_target_info()
				_refresh_target_highlights()
				queue_redraw()
			else:
				AudioRouter.play_sfx("ui", "denied")
				hud.action_menu.refuse()
			return
		pending_move = entry.move
		if target_selector.open(unit, runtime):
			state = State.SELECT_TARGET
			_refresh_target_info()
			_refresh_target_highlights()
			queue_redraw()


func _target_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		target_selector.cycle(-1)
		AudioRouter.play_sfx("ui", "move")
		_refresh_target_info()
		_refresh_target_highlights()
		queue_redraw()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		target_selector.cycle(1)
		AudioRouter.play_sfx("ui", "move")
		_refresh_target_info()
		_refresh_target_highlights()
		queue_redraw()
	elif event.is_action_pressed("cancel"):
		AudioRouter.play_sfx("ui", "cancel")
		hud.hide_info()
		_clear_target_side()
		if pending_item != "":
			# Back to the bag, not all the way to the commands.
			pending_item = ""
			state = State.SELECT_MENU
			hud.show_menu(_current_unit(), runtime.can_flee(), available_inventory())
			menu_mode = "items"
			hud.action_menu.build_items(_current_unit(), available_inventory())
			return
		_open_menu_for_current()
	elif event.is_action_pressed("interact"):
		AudioRouter.play_sfx("ui", "confirm")
		var unit := _current_unit()
		var target := target_selector.current()
		if sprites.has(target):
			sprites[target].flash_confirm()
		if pending_item != "":
			_commit_action({"actor": unit, "kind": "item", "move": {}, "target": target, "item_id": pending_item})
			pending_item = ""
			return
		_commit_action({
			"actor": unit, "kind": "move",
			"move": pending_move, "target": target,
		})
		queue_redraw()


func _refresh_target_info() -> void:
	if pending_item != "":
		var target := target_selector.current()
		var item := GameData.get_item(pending_item)
		hud.show_info("%s\n%s  HP %d/%d\n%s" % [str(item.get("name", "")), target.display_name, target.hp, target.max_hp, str(item.get("description", ""))])
		return
	hud.show_info(target_selector.estimate_text(_current_unit(), pending_move, resolver))


func available_inventory() -> Dictionary:
	## The bag minus items already committed this round.
	var bag := runtime.inventory.duplicate()
	for action in planned_actions:
		if action.kind == "item":
			bag[action.item_id] = int(bag.get(action.item_id, 0)) - 1
	return bag


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
	_clear_all_highlights()
	queue_redraw()

	# The resolver owns every rule (Resonance, phases, telegraphs, damage
	# over time); presentation only plays back the authoritative events.
	var all_actions := planned_actions.duplicate()
	all_actions.append_array(resolver.plan_enemy_actions())
	var ordered := resolver.order_actions(all_actions)
	for action in ordered:
		if runtime.outcome() != "":
			break
		if not action.actor.is_alive():
			continue
		var events := resolver.execute(action)
		await presentation.play_events(action, events)
		hud.refresh_rows()

	var round_end := resolver.end_round()
	await presentation.play_round_end(round_end)
	_show_objective()
	hud.refresh_rows()
	for sprite in sprites.values():
		sprite.refresh()

	match runtime.outcome():
		"victory":
			_finish(true)
		"defeat":
			_finish(false)
		_:
			_start_selection()


func _on_summoned(unit: BattleUnit) -> void:
	## A boss phase brought a new enemy onto the field.
	for existing in runtime.all_units():
		if not sprites.has(existing):
			sprites[existing] = (stage as BattleStage).add_combatant(existing, runtime.enemy_units.size(), runtime.player_units.size())
	hud.build_turn_rail(runtime.all_units())
	hud.refresh_rows()


func _play_events(action: Dictionary, events: Array) -> void:
	## Compatibility entry point for tools/tests; all sequencing lives in one layer.
	await presentation.play_events(action, events)



func _show_objective() -> void:
	## The objective and, where it counts, its progress ("Survive the Assault 2/4").
	var objective: Dictionary = GameData.get_objective(runtime.encounter.get("objective", "defeat_all"))
	var progress := runtime.objective_progress()
	hud.set_objective(str(objective.get("name", "Defeat all enemies")) + ("  " + progress if progress != "" else ""))


# ── Battle end ───────────────────────────────────────────────────────

func _finish(player_won: bool) -> void:
	state = State.RESULT
	hud.hide_menu()
	hud.hide_info()
	hud.set_phase("VICTORY" if player_won else "DEFEAT")
	hud.set_message("")
	var rewards: Array = []
	if player_won:
		GameState.store_battle_results(runtime.player_units, runtime.inventory)
		rewards = GameState.grant_encounter_rewards(runtime.encounter)
	# Story battles offer Retry unless data says otherwise; field battles only
	# when they opt in (an optional boss), so roadside losses still send you home.
	var can_retry := not player_won and bool(runtime.encounter.get("retry", GameState.world_battle.is_empty()))
	result_presentation = ResultPresentation.new()
	add_child(result_presentation)
	result_presentation.chose.connect(_after_result.bind(player_won))
	result_presentation.show_result(player_won, rewards, can_retry)


func _after_result(choice: String, player_won: bool) -> void:
	if choice == "retry":
		# Same battle, same HP and supplies as when it began.
		GameState.restore_retry_snapshot()
		SceneTransition.change_scene(BATTLE_SCENE, "spectral")
		return
	if GameState.mode == "quick":
		# Quick Battle never enters the story: back to its own screen.
		SceneTransition.change_scene(QUICK_BATTLE_SCENE, "gold" if player_won else "defeat")
		return
	if not GameState.world_battle.is_empty():
		if player_won:
			_leave_after_victory()
		else:
			SceneTransition.change_scene(GameState.finish_world_battle("defeat"), "defeat")
		return
	var key: String = runtime.encounter.get("victory_dialogue" if player_won else "defeat_dialogue", "")
	if key != "" and dialogue.has_key(key):
		dialogue.play(key)
	elif player_won:
		_leave_after_victory()
	else:
		_leave_after_defeat()


func _leave_after_defeat() -> void:
	## Giving up a story battle: back to the last recovery point, rested.
	GameState.restore_retry_snapshot()
	if GameState.checkpoint.is_empty():
		SceneTransition.change_scene(BOOT_SCENE, "defeat")
		return
	GameState.recover_party()
	GameState.location_id = str(GameState.checkpoint.location)
	GameState.location_spawn = str(GameState.checkpoint.spawn)
	GameState.current_scene = str(WorldCatalog.location(GameState.location_id).scene)
	SaveManager.save_game()
	SceneTransition.change_scene(GameState.current_scene, "defeat")


func _try_flee() -> void:
	if state != State.SELECT_MENU or GameState.world_battle.is_empty(): return
	if not runtime.flee(): return
	state = State.RESULT
	hud.hide_menu()
	hud.hide_info()
	# Carry damage and spent supplies into the field.
	GameState.store_battle_results(runtime.player_units, runtime.inventory)
	SceneTransition.change_scene(GameState.finish_world_battle("fled"), "travel")


func _leave_after_victory() -> void:
	var encounter_id: String = runtime.encounter.get("id", GameState.pending_encounter)
	# Every won encounter is recorded the same way, wherever it was fought.
	GameState.set_flag("%s_won" % encounter_id)
	var after: Dictionary = runtime.encounter.get("return", {})
	if not GameState.world_battle.is_empty():
		var scene := GameState.finish_world_battle("victory")
		if after.is_empty():
			SceneTransition.change_scene(scene, "gold")
			return
	# Story battles say in data where play resumes and what they unlock.
	for flag_name in after.get("flags", []):
		GameState.set_flag(str(flag_name))
	if not after.is_empty():
		GameState.location_id = str(after.get("location", GameState.location_id))
		GameState.location_spawn = str(after.get("spawn", ""))
		GameState.current_scene = str(WorldCatalog.location(GameState.location_id).get("scene", GameState.current_scene))
		SaveManager.save_game()
		SceneTransition.change_scene(GameState.current_scene, "gold")
		return
	if GameState.pending_encounter == "hollow_court_battle":
		GameState.set_flag("hollow_court_cleared")
		GameState.set_flag("post_battle_scene_pending")
		# WorldLocation resolves this named spawn from the authored map.
		GameState.location_id = "greymere"
		GameState.location_spawn = "court_return"
	SaveManager.save_game()
	SceneTransition.change_scene(OVERWORLD_SCENE, "gold")


# Selection/target markers now live on DuelistSprite itself
# (set_highlighted/flash_confirm), sized from the sprite's own manifest
# instead of a hardcoded box here — see _clear_all_highlights and
# _refresh_target_highlights above.
