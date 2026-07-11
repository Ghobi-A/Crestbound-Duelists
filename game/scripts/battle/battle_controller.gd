extends Node2D
## The Hollow Court — tactical battle prototype (3v3, 8x6 grid).
##
## Player: Aren (chosen class + Crest), Warden Elara Thorne
## (Guardian/Azure), Mira Solen (Mage/Ember) vs a Riven-touched Raider
## (Warrior), a Hexbound Adept (Sorcerer), and an Unbound Mercenary
## (Neutral). Objective: defeat all enemies.
##
## All stats, moves, Crest behaviour, and combat constants come from
## GameData (exported by the Python Balance Lab).

const TILE := 16
const GRID_OFFSET := Vector2(30, 42)
const OVERWORLD_SCENE := "res://scenes/overworld/greymere.tscn"
const BOOT_SCENE := "res://scenes/boot/boot.tscn"
const COURT_RETURN_TILE := Vector2i(11, 2)

const TERRAIN_LAYOUT: Array[String] = [
	".r....r.",
	"........",
	"..w..n..",
	"...w....",
	"........",
	".r....r.",
]
const TERRAIN_LEGEND := {
	".": "plains", "r": "ruin", "w": "wall", "n": "crest_node", "f": "forest",
}

const PLAYER_SPAWNS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(0, 1), Vector2i(0, 4)]
const ENEMY_BUILDS := [
	{"name": "Riven-touched Raider", "class_id": "warrior", "crest_id": ""},
	{"name": "Hexbound Adept", "class_id": "sorcerer", "crest_id": ""},
	{"name": "Unbound Mercenary", "class_id": "neutral", "crest_id": ""},
]
const ENEMY_SPAWNS: Array[Vector2i] = [Vector2i(6, 2), Vector2i(7, 1), Vector2i(7, 4)]

enum Phase { INTRO, PLAYER, ENEMY, RESULT }
enum InputState { CURSOR, MOVE_SELECT, ACTION_MENU, TARGET_SELECT }

var grid := BattleGrid.new()
var units: Array = []          # all BattleUnits, player first
var views: Dictionary = {}     # BattleUnit -> BattleUnitView
var hud: BattleHud
var dialogue: DialogueBox
var rng := RandomNumberGenerator.new()

var phase: Phase = Phase.INTRO
var input_state: InputState = InputState.CURSOR
var round_number := 1
var cursor := Vector2i(0, 0)

var selected: BattleUnit = null
var reachable: Dictionary = {}
var original_tile := Vector2i.ZERO
var menu_entries: Array = []
var menu_index := 0
var pending_move: Dictionary = {}
var targets: Array = []
var target_index := 0

var _unit_layer: Node2D


func _ready() -> void:
	rng.randomize()
	grid.setup(TERRAIN_LAYOUT, TERRAIN_LEGEND, GameData)
	_unit_layer = Node2D.new()
	_unit_layer.position = GRID_OFFSET
	add_child(_unit_layer)
	_spawn_units()
	_build_hud()
	_build_dialogue()
	hud.set_objective(GameData.get_objective("defeat_all").get("name", "Defeat all enemies"))
	hud.set_phase("The Hollow Court")
	dialogue.play("battle_intro")


func _spawn_units() -> void:
	if GameState.party.is_empty():
		GameState.player_name = GameState.DEFAULT_PLAYER_NAME
		GameState.start_new_game("warrior")  # dev fallback when run directly
	for i in GameState.party.size():
		var unit := BattleUnit.create(GameState.party[i], "player", GameData)
		unit.tile = PLAYER_SPAWNS[i]
		_add_unit(unit)
	for i in ENEMY_BUILDS.size():
		var unit := BattleUnit.create(ENEMY_BUILDS[i], "enemy", GameData)
		unit.tile = ENEMY_SPAWNS[i]
		_add_unit(unit)


func _add_unit(unit: BattleUnit) -> void:
	units.append(unit)
	var view := BattleUnitView.new()
	_unit_layer.add_child(view)
	view.setup(unit)
	views[unit] = view


func _build_hud() -> void:
	hud = BattleHud.new()
	add_child(hud)


func _build_dialogue() -> void:
	dialogue = DialogueBox.new()
	dialogue.load_file("res://data/dialogue/hollow_court.json")
	dialogue.dialogue_finished.connect(_on_dialogue_finished)
	add_child(dialogue)


func _on_dialogue_finished(key: String) -> void:
	match key:
		"battle_intro":
			_start_player_phase()
		"battle_victory":
			GameState.set_flag("hollow_court_cleared")
			GameState.set_flag("post_battle_scene_pending")
			GameState.player_tile = COURT_RETURN_TILE
			SaveManager.save_game()
			get_tree().change_scene_to_file(OVERWORLD_SCENE)
		"battle_defeat":
			get_tree().change_scene_to_file(BOOT_SCENE)


# ── Phase control ────────────────────────────────────────────────────

func _team_units(team: String) -> Array:
	return units.filter(func(u): return u.team == team and u.is_alive())


func _start_player_phase() -> void:
	phase = Phase.PLAYER
	input_state = InputState.CURSOR
	for unit in _team_units("player"):
		unit.acted = false
		unit.on_turn_start()
		views[unit].refresh()
	hud.set_phase("Round %d — PLAYER PHASE" % round_number)
	hud.set_message("")
	cursor = _team_units("player")[0].tile
	_refresh_hover()
	queue_redraw()


func _start_enemy_phase() -> void:
	phase = Phase.ENEMY
	hud.set_phase("Round %d — ENEMY PHASE" % round_number)
	hud.clear_menu()
	hud.clear_preview()
	queue_redraw()
	_run_enemy_phase()


func _run_enemy_phase() -> void:
	# Sequential AI turns with short pauses so the player can follow.
	for unit in _team_units("enemy"):
		unit.acted = false
		unit.on_turn_start()
		views[unit].refresh()
	for unit in _team_units("enemy"):
		if not unit.is_alive():
			continue
		await get_tree().create_timer(0.4).timeout
		await _enemy_take_turn(unit)
		if _check_battle_end():
			return
	round_number += 1
	_start_player_phase()


func _finish_unit_turn(unit: BattleUnit) -> void:
	unit.on_turn_end()
	views[unit].refresh()
	selected = null
	pending_move = {}
	input_state = InputState.CURSOR
	hud.clear_menu()
	hud.clear_preview()
	queue_redraw()
	if _check_battle_end():
		return
	if phase == Phase.PLAYER and _team_units("player").all(func(u): return u.acted):
		_start_enemy_phase()


func _check_battle_end() -> bool:
	if _team_units("enemy").is_empty():
		phase = Phase.RESULT
		hud.set_phase("VICTORY")
		hud.set_message("The Hollow Court falls silent.")
		dialogue.play("battle_victory")
		return true
	if _team_units("player").is_empty():
		phase = Phase.RESULT
		hud.set_phase("DEFEAT")
		hud.set_message("The party is overwhelmed...")
		dialogue.play("battle_defeat")
		return true
	return false


# ── Player input ─────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.PLAYER or dialogue.active:
		return
	if not event.is_pressed() or event.is_echo():
		return
	match input_state:
		InputState.CURSOR:
			_input_cursor(event)
		InputState.MOVE_SELECT:
			_input_move_select(event)
		InputState.ACTION_MENU:
			_input_action_menu(event)
		InputState.TARGET_SELECT:
			_input_target_select(event)


func _cursor_delta(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("move_up"):
		return Vector2i(0, -1)
	if event.is_action_pressed("move_down"):
		return Vector2i(0, 1)
	if event.is_action_pressed("move_left"):
		return Vector2i(-1, 0)
	if event.is_action_pressed("move_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO


func _input_cursor(event: InputEvent) -> void:
	var delta := _cursor_delta(event)
	if delta != Vector2i.ZERO:
		var next := cursor + delta
		if grid.in_bounds(next):
			cursor = next
			_refresh_hover()
			queue_redraw()
		return
	if event.is_action_pressed("interact"):
		var unit := _unit_at(cursor)
		if unit != null and unit.team == "player" and not unit.acted:
			selected = unit
			original_tile = unit.tile
			reachable = grid.reachable_tiles(unit, units)
			input_state = InputState.MOVE_SELECT
			hud.set_message("Move: choose a tile")
			queue_redraw()


func _input_move_select(event: InputEvent) -> void:
	var delta := _cursor_delta(event)
	if delta != Vector2i.ZERO:
		var next := cursor + delta
		if grid.in_bounds(next):
			cursor = next
			_refresh_hover()
			queue_redraw()
		return
	if event.is_action_pressed("cancel"):
		selected = null
		input_state = InputState.CURSOR
		hud.set_message("")
		queue_redraw()
		return
	if event.is_action_pressed("interact") and reachable.has(cursor):
		selected.tile = cursor
		views[selected].refresh()
		_open_action_menu()


func _open_action_menu() -> void:
	input_state = InputState.ACTION_MENU
	menu_entries = []
	for move in selected.moves:
		var move_id: String = move.get("id", move.name)
		var cooldown := int(selected.cooldowns.get(move_id, 0))
		var entry := {"label": move.name, "move": move, "enabled": true, "note": ""}
		if cooldown > 0:
			entry.enabled = false
			entry.note = "CD %d" % cooldown
		elif selected.is_move_blocked_by_hex(move):
			entry.enabled = false
			entry.note = "HEXED"
		menu_entries.append(entry)
	menu_entries.append({"label": "Brace", "move": null, "enabled": true, "note": ""})
	menu_entries.append({"label": "Wait", "move": null, "enabled": true, "note": ""})
	menu_index = 0
	hud.set_message("")
	hud.show_menu(menu_entries, menu_index)
	queue_redraw()


func _input_action_menu(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		menu_index = wrapi(menu_index - 1, 0, menu_entries.size())
		hud.show_menu(menu_entries, menu_index)
		return
	if event.is_action_pressed("move_down"):
		menu_index = wrapi(menu_index + 1, 0, menu_entries.size())
		hud.show_menu(menu_entries, menu_index)
		return
	if event.is_action_pressed("cancel"):
		selected.tile = original_tile
		views[selected].refresh()
		cursor = original_tile
		input_state = InputState.MOVE_SELECT
		hud.clear_menu()
		hud.set_message("Move: choose a tile")
		queue_redraw()
		return
	if event.is_action_pressed("interact"):
		var entry: Dictionary = menu_entries[menu_index]
		if not entry.enabled:
			return
		match entry.label:
			"Brace":
				selected.braced = true
				hud.set_message("%s braces." % selected.display_name)
				_finish_unit_turn(selected)
			"Wait":
				_finish_unit_turn(selected)
			_:
				pending_move = entry.move
				targets = _targets_in_range(selected, pending_move)
				if targets.is_empty():
					hud.set_message("No targets in range.")
					return
				target_index = 0
				input_state = InputState.TARGET_SELECT
				_refresh_target_preview()
				queue_redraw()


func _input_target_select(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		target_index = wrapi(target_index - 1, 0, targets.size())
		_refresh_target_preview()
		queue_redraw()
		return
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		target_index = wrapi(target_index + 1, 0, targets.size())
		_refresh_target_preview()
		queue_redraw()
		return
	if event.is_action_pressed("cancel"):
		input_state = InputState.ACTION_MENU
		hud.clear_preview()
		hud.show_menu(menu_entries, menu_index)
		queue_redraw()
		return
	if event.is_action_pressed("interact"):
		var target: BattleUnit = targets[target_index]
		hud.clear_preview()
		_execute_attack(selected, target, pending_move)
		_finish_unit_turn(selected)


func _refresh_hover() -> void:
	var unit := _unit_at(cursor)
	hud.show_unit(unit if unit != null else selected, grid)


func _refresh_target_preview() -> void:
	var target: BattleUnit = targets[target_index]
	hud.show_unit(target, grid)
	var estimate := _damage_range(selected, target, pending_move)
	hud.show_preview("%s -> %s: %d-%d dmg, %d%% hit" % [
		pending_move.name, target.display_name,
		estimate.x, estimate.y, roundi(float(pending_move.get("accuracy", 1.0)) * 100),
	])


func _unit_at(tile: Vector2i) -> BattleUnit:
	for unit in units:
		if unit.is_alive() and unit.tile == tile:
			return unit
	return null


func _targets_in_range(attacker: BattleUnit, move: Dictionary) -> Array:
	var max_range := int(move.get("range", 1))
	var result: Array = []
	for unit in units:
		if unit.is_alive() and unit.team != attacker.team:
			var d := BattleGrid.distance(attacker.tile, unit.tile)
			if d >= 1 and d <= max_range:
				result.append(unit)
	return result


# ── Combat resolution (mirrors the Python engine formulas) ──────────

func _resolve_move_type(move: Dictionary, attacker: BattleUnit, defender: BattleUnit) -> String:
	var move_type: String = move.get("move_type", "physical")
	if move_type != "adaptive":
		return move_type
	var phys := 2.0 * attacker.stat("atk") / maxf(1.0, attacker.stat("atk") + _defence_of(defender, "def"))
	var mag := 2.0 * attacker.stat("mag") / maxf(1.0, attacker.stat("mag") + _defence_of(defender, "res"))
	return "physical" if phys >= mag else "magical"


func _defence_of(defender: BattleUnit, stat_name: String) -> float:
	var value := float(defender.stat(stat_name))
	if stat_name == "def":
		value += grid.defense_bonus(defender.tile)
	else:
		value += grid.resistance_bonus(defender.tile)
	if defender.braced:
		var multiplier := GameData.config_value("brace_multiplier") + defender.brace_multiplier_bonus()
		value = floorf(value * multiplier)
	return value


func _attack_multipliers(attacker: BattleUnit, defender: BattleUnit, move: Dictionary) -> float:
	var multiplier := attacker.damage_dealt_multiplier(defender) * defender.damage_taken_multiplier()
	# Verdant passive: bonus when not repeating the previous move.
	var passive := attacker.passive()
	if passive.get("type", "") == "variety_bonus":
		var move_id: String = move.get("id", move.name)
		if attacker.last_move_id != "" and attacker.last_move_id != move_id:
			multiplier += float(passive.get("amount", 0.0))
	# Crimson awakening: empowered Gambit.
	if move.get("slot", "") == "gambit" and attacker.awakening_effect_active("empowered_gambit"):
		multiplier += float(attacker.crest_record.awakening_effect.get("power_bonus", 0.0))
	# Glass awakening: sharpened everything.
	if attacker.awakening_effect_active("perfect_edge"):
		multiplier += float(attacker.crest_record.awakening_effect.get("power_bonus", 0.0))
	return multiplier


func _damage_range(attacker: BattleUnit, defender: BattleUnit, move: Dictionary) -> Vector2i:
	var resolved := _resolve_move_type(move, attacker, defender)
	var atk := float(attacker.stat("atk" if resolved == "physical" else "mag"))
	var def_value := _defence_of(defender, "def" if resolved == "physical" else "res")
	var ratio := 2.0 * atk / maxf(1.0, atk + def_value)
	var base := float(move.get("power", 0)) * ratio * _attack_multipliers(attacker, defender, move)
	var low := maxi(1, floori(base * GameData.config_value("variance_low")))
	var high := maxi(1, floori(base * GameData.config_value("variance_high")))
	return Vector2i(low, high)


func _execute_attack(attacker: BattleUnit, defender: BattleUnit, move: Dictionary) -> void:
	attacker.note_move_used(move)

	var accuracy := float(move.get("accuracy", 1.0))
	if attacker.awakening_effect_active("perfect_edge"):
		accuracy = maxf(accuracy, float(attacker.crest_record.awakening_effect.get("accuracy_override", 1.0)))
	if rng.randf() >= accuracy:
		hud.set_message("%s: %s missed!" % [attacker.display_name, move.name])
		return

	var estimate := _damage_range(attacker, defender, move)
	var damage := rng.randi_range(estimate.x, estimate.y)
	defender.take_damage(damage)
	hud.set_message("%s: %s hits %s for %d." % [
		attacker.display_name, move.name, defender.display_name, damage,
	])

	# Crimson awakening: lifesteal on the empowered Gambit.
	if move.get("slot", "") == "gambit" and attacker.awakening_effect_active("empowered_gambit"):
		var steal := int(damage * float(attacker.crest_record.awakening_effect.get("lifesteal", 0.0)))
		if steal > 0:
			attacker.heal(steal)

	# Azure awakening: counter stance reflects part of the damage.
	if defender.is_alive() and defender.awakening_effect_active("counter_stance"):
		var reflected := maxi(1, floori(damage * float(defender.crest_record.awakening_effect.get("counter_damage", 0.0))))
		attacker.take_damage(reflected)
		hud.set_message("%s counters for %d!" % [defender.display_name, reflected])

	if move.get("slot", "") == "gambit":
		attacker.gambits_landed += 1

	var decay := int(GameData.config_value("stat_decay_duration"))
	for mod in move.get("target_stat_mods", []):
		defender.apply_stat_mod(mod.stat, int(mod.amount), decay)
		if int(mod.amount) < 0:
			attacker.debuffs_applied += 1
	# Hex prevents a unit from strengthening itself (mirrors the 1v1 engine).
	if not (move.get("self_stat_mods", []).size() > 0 and attacker.has_status("hexed")):
		for mod in move.get("self_stat_mods", []):
			attacker.apply_stat_mod(mod.stat, int(mod.amount), decay)

	for effect in move.get("status_effects", []):
		var duration := int(effect.get("duration", 1)) + attacker.status_duration_bonus()
		defender.apply_status(effect.get("status", ""), duration)
		attacker.statuses_applied += 1
		# Eclipse awakening: Hex also disturbs the target's cooldowns.
		if attacker.awakening_effect_active("hex_saturation"):
			for move_id in defender.cooldowns:
				defender.cooldowns[move_id] = int(defender.cooldowns[move_id]) \
					+ int(attacker.crest_record.awakening_effect.get("cooldown_penalty", 1))

	_check_awakenings()
	views[attacker].refresh()
	views[defender].refresh()
	if not defender.is_alive():
		hud.set_message("%s falls!" % defender.display_name)


func _check_awakenings() -> void:
	for unit in units:
		if unit.is_alive() and unit.check_awakening():
			hud.set_message("%s's %s awakens!" % [
				unit.display_name, unit.crest_record.get("name", "Crest"),
			])
			views[unit].refresh()


# ── Enemy AI (greedy, mirrors the Balance Lab's greedy policy) ──────

func _enemy_take_turn(unit: BattleUnit) -> void:
	var enemy_reachable := grid.reachable_tiles(unit, units)
	var best := {"score": -1.0}
	for move in unit.available_moves():
		if unit.is_move_blocked_by_hex(move):
			continue
		var max_range := int(move.get("range", 1))
		for target in _team_units("player"):
			for tile in enemy_reachable:
				var d: int = BattleGrid.distance(tile, target.tile)
				if d < 1 or d > max_range:
					continue
				var previous_tile := unit.tile
				unit.tile = tile
				var estimate := _damage_range(unit, target, move)
				unit.tile = previous_tile
				var mid := (estimate.x + estimate.y) / 2.0 * float(move.get("accuracy", 1.0))
				var score := mid + (1000.0 if estimate.y >= target.hp else 0.0)
				if score > float(best.score):
					best = {"score": score, "move": move, "target": target, "tile": tile}
	if best.score >= 0.0:
		unit.tile = best.tile
		views[unit].refresh()
		queue_redraw()
		await get_tree().create_timer(0.3).timeout
		_execute_attack(unit, best.target, best.move)
	else:
		# No attack available: advance toward the nearest player and Brace.
		var nearest: BattleUnit = null
		for target in _team_units("player"):
			if nearest == null or BattleGrid.distance(unit.tile, target.tile) < BattleGrid.distance(unit.tile, nearest.tile):
				nearest = target
		var best_tile := unit.tile
		for tile in enemy_reachable:
			if BattleGrid.distance(tile, nearest.tile) < BattleGrid.distance(best_tile, nearest.tile):
				best_tile = tile
		unit.tile = best_tile
		unit.braced = true
		hud.set_message("%s advances and braces." % unit.display_name)
	unit.on_turn_end()
	views[unit].refresh()
	queue_redraw()


# ── Drawing ──────────────────────────────────────────────────────────

func _draw() -> void:
	for y in grid.height:
		for x in grid.width:
			var tile := Vector2i(x, y)
			var rect := Rect2(GRID_OFFSET + Vector2(tile * TILE), Vector2(TILE, TILE))
			draw_rect(rect, _terrain_color(grid.terrain_ids.get(tile, "plains")))
			draw_rect(rect, Color(0, 0, 0, 0.25), false, 1.0)

	if phase != Phase.PLAYER:
		return

	if input_state == InputState.MOVE_SELECT:
		for tile in reachable:
			draw_rect(Rect2(GRID_OFFSET + Vector2(tile * TILE), Vector2(TILE, TILE)), PlaceholderPalette.OVERLAY_MOVE)
	if input_state == InputState.TARGET_SELECT and selected != null:
		for tile in BattleGrid.tiles_in_range(selected.tile, 1, int(pending_move.get("range", 1))):
			if grid.in_bounds(tile):
				draw_rect(Rect2(GRID_OFFSET + Vector2(tile * TILE), Vector2(TILE, TILE)), PlaceholderPalette.OVERLAY_ATTACK)
		var target: BattleUnit = targets[target_index]
		draw_rect(Rect2(GRID_OFFSET + Vector2(target.tile * TILE), Vector2(TILE, TILE)), PlaceholderPalette.OVERLAY_CURSOR, false, 1.0)
	if selected != null:
		draw_rect(Rect2(GRID_OFFSET + Vector2(selected.tile * TILE), Vector2(TILE, TILE)), PlaceholderPalette.OVERLAY_SELECTED, false, 1.0)
	if input_state in [InputState.CURSOR, InputState.MOVE_SELECT]:
		draw_rect(Rect2(GRID_OFFSET + Vector2(cursor * TILE), Vector2(TILE, TILE)), PlaceholderPalette.OVERLAY_CURSOR, false, 1.0)


func _terrain_color(terrain_id: String) -> Color:
	match terrain_id:
		"ruin":
			return PlaceholderPalette.TILE_RUIN
		"wall":
			return PlaceholderPalette.TILE_WALL
		"forest":
			return PlaceholderPalette.TILE_FOREST
		"crest_node":
			return PlaceholderPalette.TILE_CREST_NODE
		"scorched":
			return PlaceholderPalette.TILE_SCORCHED
		_:
			return PlaceholderPalette.TILE_PLAINS
