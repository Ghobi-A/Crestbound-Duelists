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

## Background height must match where the HUD's opaque bottom panel
## starts (battle_hud.gd) or a seam shows between the floor and the
## panel. tools/generate_sprites.py generates backgrounds at this size.
const BACKGROUND_HEIGHT := 122

## Formation staging. Two clear halves rather than a shared diagonal, so
## the sides read as opposing at a glance; front/back use one shared
## depth convention for both teams — front is always closer to the
## camera (larger Y) — so the read is consistent instead of mirrored.
const PLAYER_CENTER_X := 88.0
const ENEMY_CENTER_X := 232.0
const FRONT_Y := 92.0
const BACK_Y := 68.0
const ONBOARDING_FLAG := "battle_onboarding_seen"
const ONBOARDING_TITLE := "BATTLE BASICS"
const ONBOARDING_BODY := "Choose each Duelist's action and target.\nBrace acts first and reduces incoming damage.\nBuild Resonance to awaken your Crest."

enum State { INTRO, SELECT_MENU, SELECT_TARGET, PREVIEW, RESOLVING, RESULT }

var runtime: EncounterRuntime
var resolver: BattleResolver
var crest_runtime: CrestRuntime
var hud: BattleHud
var dialogue: DialogueBox
var target_selector := TargetSelector.new()

var state: State = State.INTRO
var sprites: Dictionary = {}      # BattleUnit -> DuelistSprite
var selection_order: Array = []   # living player units, selection sequence
var selection_index := 0
var planned_actions: Array = []
var pending_move: Dictionary = {}
var stage: Node2D                 # background + unit sprites (shakeable)
var onboarding: OnboardingPanel
var presentation: BattlePresentation
var result_presentation: ResultPresentation


func _ready() -> void:
	runtime = EncounterRuntime.start(GameState.pending_encounter, GameData, GameState)
	resolver = BattleResolver.new(runtime, GameData)
	crest_runtime = CrestRuntime.new(runtime)
	stage = Node2D.new()
	add_child(stage)
	_stage_background()
	_stage_units()
	_build_hud()
	presentation = BattlePresentation.new()
	add_child(presentation)
	presentation.configure(stage, hud, sprites)
	AudioRouter.play_music("battle")
	_build_dialogue()
	_build_onboarding()
	var objective: Dictionary = GameData.get_objective(runtime.encounter.get("objective", "defeat_all"))
	hud.set_objective(objective.get("name", "Defeat all enemies"))
	hud.set_phase(str(runtime.encounter.get("name", "Battle")))
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
	var location: String = runtime.encounter.get("location", "")
	_stage_background_layer("%s_far" % location, -20)
	var path := "res://assets/battle/backgrounds/%s.png" % location
	if ResourceLoader.exists(path):
		var background := Sprite2D.new()
		background.texture = load(path)
		background.centered = false
		VisualAsset.fit_sprite(background, VisualAsset.sidecar_for(path), Rect2(0, 0, 320, BACKGROUND_HEIGHT))
		background.z_index = -10
		stage.add_child(background)
	else:
		var fallback := ColorRect.new()
		fallback.color = PlaceholderPalette.BG_DARK
		fallback.size = Vector2(320, BACKGROUND_HEIGHT)
		fallback.z_index = -10
		stage.add_child(fallback)
	_stage_background_layer("%s_foreground" % location, 105)


func _stage_background_layer(asset_key: String, z: int) -> void:
	## Optional authored far/foreground plates use transparent PNGs and the same
	## crop contract. Foreground authors must keep the sidecar safe area clear.
	var path := "res://assets/battle/backgrounds/%s.png" % asset_key
	if not ResourceLoader.exists(path):
		return
	var layer := Sprite2D.new()
	layer.texture = load(path)
	layer.centered = false
	layer.z_index = z
	VisualAsset.fit_sprite(layer, VisualAsset.sidecar_for(path), Rect2(0, 0, 320, BACKGROUND_HEIGHT))
	stage.add_child(layer)


func _stage_units() -> void:
	for unit in runtime.all_units():
		var sprite := DuelistSprite.new()
		stage.add_child(sprite)
		var home := stage_position(unit)
		sprite.configure(unit, home)
		# Back-row units must draw behind front-row units regardless of
		# team or add order, so the depth the Y position implies is
		# never contradicted by draw order.
		sprite.z_index = int(home.y)
		sprites[unit] = sprite


func stage_position(unit: BattleUnit) -> Vector2:
	## Dynamic staging: players occupy the left half, enemies the right,
	## so the two sides read as opposing formations at a glance. Front
	## and back rows use one shared depth convention for both teams —
	## front is always closer to the camera — rather than a convention
	## that reversed between sides. Back rows draw slightly narrower
	## than front rows, a shallow wedge that reinforces "protected" depth
	## without any grid or movement implication.
	var team_units: Array = runtime.player_units if unit.team == "player" else runtime.enemy_units
	var count := team_units.size()
	var center_x := PLAYER_CENTER_X if unit.team == "player" else ENEMY_CENTER_X
	var is_front := unit.position == "front"

	var spread := 46.0 if count < 3 else 40.0
	if not is_front:
		spread *= 0.7
	var x := center_x + (unit.slot_index - (count - 1) / 2.0) * spread
	var y := FRONT_Y if is_front else BACK_Y
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
		SceneTransition.change_scene(BOOT_SCENE, "defeat")


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
	_clear_all_highlights()
	var unit := _current_unit()
	hud.highlight_unit(unit)
	hud.show_menu(unit)
	if sprites.has(unit):
		sprites[unit].set_highlighted("selected")
	queue_redraw()


# ── Target highlighting (presentation only; target_selector.gd,
# battle_resolver.gd, battle_unit.gd and encounter_runtime.gd are never
# touched by any of this) ─────────────────────────────────────────────

func _clear_all_highlights() -> void:
	for u in sprites:
		sprites[u].clear_highlight()
	_clear_target_dim()


func _clear_target_dim() -> void:
	for u in sprites:
		sprites[u].modulate = Color.WHITE


func _clear_target_side() -> void:
	for u in target_selector.targets:
		if sprites.has(u):
			sprites[u].clear_highlight()
	_clear_target_dim()


func _refresh_target_highlights() -> void:
	var current := target_selector.current()
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
		if selection_index > 0:
			_reopen_last_selection()
	elif event.is_action_pressed("interact"):
		AudioRouter.play_sfx("ui", "confirm")
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
		_open_menu_for_current()
	elif event.is_action_pressed("interact"):
		AudioRouter.play_sfx("ui", "confirm")
		var unit := _current_unit()
		var target := target_selector.current()
		if sprites.has(target):
			sprites[target].flash_confirm()
		_commit_action({
			"actor": unit, "kind": "move",
			"move": pending_move, "target": target,
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
	_clear_all_highlights()
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
		# Resolve all Crest state immediately from authoritative events; presentation
		# receives only the result and cannot decide combat state.
		var awakenings: Array[BattleUnit] = []
		for event in events:
			if event.type == "crest":
				var crest_result: Dictionary = crest_runtime.process_event(event.unit, event.event)
				event["presentation_result"] = crest_result
				if crest_result.awakened:
					awakenings.append(event.unit)
		await presentation.play_events(action, events)
		for awakened_unit in awakenings:
			await _play_awakening(awakened_unit)
		hud.refresh_rows()

	resolver.end_round()
	await _after_round_tick()
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
	for unit in crest_runtime.end_of_round_awakenings():
		await _play_awakening(unit)


func _play_events(action: Dictionary, events: Array) -> void:
	## Compatibility entry point for tools/tests; all sequencing lives in one layer.
	await presentation.play_events(action, events)


func _play_awakening(unit: BattleUnit) -> void:
	var theme: Dictionary = unit.crest_record.get("visual_theme", {})
	var accent := _palette_accent(theme.get("palette", ""))
	hud.set_message("%s's Crest answers!" % unit.display_name)
	hud.refresh_rows()
	await presentation.play_awakening(unit, CrestRuntime.awakening_banner_text(unit), accent)


func _palette_accent(palette: String) -> Color:
	match palette:
		"crimson":
			return Color("c94f4f")
		"azure":
			return Color("4a9eff")
		"ember":
			return Color("d3743f")
		"violet_black":
			return Color("7c5fd3")
		"pale_glass":
			return Color("cfe6ef")
		"verdant":
			return Color("57c26b")
		_:
			return Color(1.0, 0.85, 0.3)



# ── Battle end ───────────────────────────────────────────────────────

func _finish(player_won: bool) -> void:
	state = State.RESULT
	hud.hide_menu()
	hud.hide_info()
	hud.set_phase("VICTORY" if player_won else "DEFEAT")
	hud.set_message("")
	result_presentation = ResultPresentation.new()
	add_child(result_presentation)
	result_presentation.acknowledged.connect(_after_result.bind(player_won))
	result_presentation.show_result(player_won)


func _after_result(player_won: bool) -> void:
	var key: String = runtime.encounter.get("victory_dialogue" if player_won else "defeat_dialogue", "")
	if key != "" and dialogue.has_key(key):
		dialogue.play(key)
	elif player_won:
		_leave_after_victory()
	else:
		SceneTransition.change_scene(BOOT_SCENE, "defeat")


func _leave_after_victory() -> void:
	var encounter_id: String = runtime.encounter.get("id", GameState.pending_encounter)
	GameState.set_flag("%s_won" % encounter_id)
	if GameState.pending_encounter == "hollow_court_battle":
		GameState.set_flag("hollow_court_cleared")
		GameState.set_flag("post_battle_scene_pending")
		GameState.player_tile = COURT_RETURN_TILE
	SaveManager.save_game()
	SceneTransition.change_scene(OVERWORLD_SCENE, "gold")


# Selection/target markers now live on DuelistSprite itself
# (set_highlighted/flash_confirm), sized from the sprite's own manifest
# instead of a hardcoded box here — see _clear_all_highlights and
# _refresh_target_highlights above.
