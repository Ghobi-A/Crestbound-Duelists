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
## panel. See PresentationMetrics.BATTLE_BACKGROUND_HEIGHT for why this
## isn't simply the old value doubled.
const BACKGROUND_HEIGHT := PresentationMetrics.BATTLE_BACKGROUND_HEIGHT

## Formation staging. Two clear halves rather than a shared diagonal, so
## the sides read as opposing at a glance; front/back use one shared
## depth convention for both teams — front is always closer to the
## camera (larger Y) — so the read is consistent instead of mirrored.
##
## These are NOT the 320x180-era values doubled — doubling them
## verbatim reproduces the exact overlap bug that motivated this
## migration. Solved from the actual regenerated sidecar widths
## (characters at 76px tall: 64-99px player, 67-102px enemy), checking
## three constraints together rather than one at a time — an earlier
## pass here (88px-tall art, spread=116/112) satisfied same-team
## adjacency but not the canvas edge, and a real screenshot caught the
## rightmost enemy slot clipping off the right edge:
##
##   1. same-team adjacency: spread must clear the widest same-team
##      pair (player: Warrior 99px + Elara 93px = 96px centre-to-centre)
##   2. canvas edge: the outermost slot's sprite half-width must not
##      cross the canvas edge — the constraint the first pass missed
##   3. inter-team gap: the two teams' innermost 3-wide-fan slots must
##      not reach each other
##
## PLAYER_CENTER_X/ENEMY_CENTER_X/spread below satisfy all three with a
## positive (if tight, ~10-17px) margin on every one; verified against
## a real captured screenshot, not just arithmetic.
const PLAYER_CENTER_X := 160.0
const ENEMY_CENTER_X := 478.0
const FRONT_Y := 184.0
const BACK_Y := 136.0
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


func _ready() -> void:
	runtime = EncounterRuntime.start(GameState.pending_encounter, GameData, GameState)
	resolver = BattleResolver.new(runtime, GameData)
	crest_runtime = CrestRuntime.new(runtime)
	stage = Node2D.new()
	add_child(stage)
	_stage_background()
	_stage_units()
	_build_hud()
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
	var path := "res://assets/battle/backgrounds/%s.png" % location
	if ResourceLoader.exists(path):
		var background := Sprite2D.new()
		background.texture = load(path)
		background.centered = false
		stage.add_child(background)
	else:
		var fallback := ColorRect.new()
		fallback.color = PlaceholderPalette.BG_DARK
		fallback.size = Vector2(PresentationMetrics.CANVAS_SIZE.x, BACKGROUND_HEIGHT)
		stage.add_child(fallback)


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


func _shake(strength: float = 2.0) -> void:
	var tween := create_tween()
	tween.tween_property(stage, "position", Vector2(strength, 0), 0.04)
	tween.tween_property(stage, "position", Vector2(-strength, 1), 0.05)
	tween.tween_property(stage, "position", Vector2.ZERO, 0.06)


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

	# 130/100 (not the old 46/40 doubled) are the front-row spread that
	# clears the widest same-team sidecar pairing at this canvas size,
	# with room left for the canvas-edge and inter-team constraints too
	# — see the const-block comment above. The back-row 0.7 shrink is
	# preserved from the original composition intent (a "protected
	# depth" wedge) but is not independently collision-proven the way
	# front-row spacing is: an all-back-row formation of three
	# maximum-width characters is a real, accepted residual risk rather
	# than a guarantee, since demanding that case be provably safe too
	# would require a front-row spread wide enough to push 3-unit
	# formations off the 640px canvas entirely.
	var spread := 130.0 if count < 3 else 100.0
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
			_refresh_target_highlights()
			queue_redraw()


func _target_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		target_selector.cycle(-1)
		_refresh_target_info()
		_refresh_target_highlights()
		queue_redraw()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		target_selector.cycle(1)
		_refresh_target_info()
		_refresh_target_highlights()
		queue_redraw()
	elif event.is_action_pressed("cancel"):
		hud.hide_info()
		_clear_target_side()
		_open_menu_for_current()
	elif event.is_action_pressed("interact"):
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
		await _play_events(action, events)
		hud.refresh_rows()
		await get_tree().create_timer(0.3).timeout

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
				_popup(sprites[event.protector].home_position, "GUARD", PlaceholderPalette.STEEL_GUARD)
				await get_tree().create_timer(0.3).timeout
			"damage":
				var target: BattleUnit = event.target
				_popup(sprites[target].home_position, str(event.amount), Color.WHITE)
				sprites[target].play("defeat" if event.ko else "hit")
				if action.kind == "move" and action.move.get("slot", "") == "gambit":
					_shake(3.0)
				elif event.amount >= 24:
					_shake(2.0)
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
				var result: Dictionary = crest_runtime.process_event(event.unit, event.event)
				if result.gained >= 10:
					_popup(sprites[event.unit].home_position + Vector2(10, -4), "R+%d" % result.gained, PlaceholderPalette.TILE_CREST_NODE.lightened(0.45))
				if result.awakened:
					await _play_awakening(event.unit)
		for sprite in sprites.values():
			sprite.refresh()


func _play_awakening(unit: BattleUnit) -> void:
	var theme: Dictionary = unit.crest_record.get("visual_theme", {})
	var accent := _palette_accent(theme.get("palette", ""))
	hud.play_awakening_banner(CrestRuntime.awakening_banner_text(unit), accent)
	hud.set_message("%s's Crest answers!" % unit.display_name)
	_shake(2.0)
	sprites[unit].play("awaken")
	hud.refresh_rows()
	await get_tree().create_timer(1.2).timeout


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


# Selection/target markers now live on DuelistSprite itself
# (set_highlighted/flash_confirm), sized from the sprite's own manifest
# instead of a hardcoded box here — see _clear_all_highlights and
# _refresh_target_highlights above.
