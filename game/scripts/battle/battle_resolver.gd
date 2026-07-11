extends RefCounted
class_name BattleResolver
## Pure combat logic for the round-based party battle system.
## Mirrors the Python Balance Lab formulas, reading every constant from
## GameData. Returns presentation-agnostic event lists; the controller
## animates them and (in later milestones) feeds crest/entity runtimes.
##
## An action is a Dictionary:
##   {actor: BattleUnit, kind: "move"|"brace",
##    move: Dictionary or {}, target: BattleUnit or null}
##
## Emitted events (type field): action_start, miss, blocked, damage,
## counter, lifesteal, stat_mod, status, brace, ko, crest (semantic
## resonance event for the crest runtime), retarget.

const MELEE_RANGE := 1
const BACK_ROW_MELEE_MULTIPLIER := 0.75

var runtime: EncounterRuntime
var game_data: Node
var rng := RandomNumberGenerator.new()


func _init(runtime_: EncounterRuntime, game_data_: Node) -> void:
	runtime = runtime_
	game_data = game_data_
	rng.randomize()


# ── Initiative ───────────────────────────────────────────────────────

func order_actions(actions: Array) -> Array:
	## Brace commitments resolve first; attacks then resolve by
	## probabilistic speed: score = SPD + U(0, speed_band). A speed gap
	## of at least the band guarantees order (preserving the Balance
	## Lab's speed-band spirit); close speeds stay uncertain.
	var band := game_data.config_value("speed_band")
	var scored: Array = []
	for action in actions:
		var actor: BattleUnit = action.actor
		var score := float(actor.stat("spd")) + rng.randf() * band
		if action.kind == "brace":
			score += 10000.0
		scored.append({"action": action, "score": score})
	scored.sort_custom(func(a, b): return a.score > b.score)
	return scored.map(func(entry): return entry.action)


# ── Damage estimation (UI preview + AI) ──────────────────────────────

func resolve_move_type(move: Dictionary, attacker: BattleUnit, defender: BattleUnit) -> String:
	var move_type: String = move.get("move_type", "physical")
	if move_type != "adaptive":
		return move_type
	var phys := 2.0 * attacker.stat("atk") / maxf(1.0, attacker.stat("atk") + defence_value(defender, "def"))
	var mag := 2.0 * attacker.stat("mag") / maxf(1.0, attacker.stat("mag") + defence_value(defender, "res"))
	return "physical" if phys >= mag else "magical"


func defence_value(defender: BattleUnit, stat_name: String) -> float:
	var value := float(defender.stat(stat_name))
	if defender.is_braced():
		var multiplier := game_data.config_value("brace_multiplier") + defender.brace_multiplier_bonus()
		value = floorf(value * multiplier)
	return value


func damage_multipliers(attacker: BattleUnit, defender: BattleUnit, move: Dictionary, previous_move_id: String) -> float:
	var multiplier := attacker.damage_dealt_multiplier(defender) * defender.damage_taken_multiplier()
	# Verdant passive: reward for not repeating the previous action.
	var passive := attacker.passive()
	if passive.get("type", "") == "variety_bonus":
		var move_id := attacker.move_id_of(move)
		if previous_move_id != "" and previous_move_id != move_id:
			multiplier += float(passive.get("amount", 0.0))
	# Awakening effects.
	if move.get("slot", "") == "gambit" and attacker.awakening_effect_active("empowered_gambit"):
		multiplier += float(attacker.crest_record.get("awakening_effect", {}).get("power_bonus", 0.0))
	if attacker.awakening_effect_active("perfect_edge"):
		multiplier += float(attacker.crest_record.get("awakening_effect", {}).get("power_bonus", 0.0))
	# Row rules: close moves lose force crossing to/from the back row.
	if int(move.get("range", 1)) <= MELEE_RANGE:
		if attacker.position == "back":
			multiplier *= BACK_ROW_MELEE_MULTIPLIER
		if defender.position == "back":
			multiplier *= BACK_ROW_MELEE_MULTIPLIER
	# Ash Seraph-style entity: stronger on matching battlefield ground.
	if attacker.entity_passive_type() == "terrain_damage_bonus":
		for tag in attacker.entity_passive().get("terrain_tags", []):
			if runtime.has_battlefield_tag(tag):
				multiplier += float(attacker.entity_passive().get("amount", 0.0))
				break
	return multiplier


func damage_range(attacker: BattleUnit, defender: BattleUnit, move: Dictionary, previous_move_id: String = "") -> Vector2i:
	var resolved := resolve_move_type(move, attacker, defender)
	var atk := float(attacker.stat("atk" if resolved == "physical" else "mag"))
	var def_value := defence_value(defender, "def" if resolved == "physical" else "res")
	var ratio := 2.0 * atk / maxf(1.0, atk + def_value)
	var base := float(move.get("power", 0)) * ratio \
		* damage_multipliers(attacker, defender, move, previous_move_id)
	var low := maxi(1, floori(base * game_data.config_value("variance_low")))
	var high := maxi(1, floori(base * game_data.config_value("variance_high")))
	return Vector2i(low, high)


func accuracy_of(attacker: BattleUnit, move: Dictionary) -> float:
	var accuracy := float(move.get("accuracy", 1.0))
	if attacker.awakening_effect_active("perfect_edge"):
		accuracy = maxf(accuracy, float(attacker.crest_record.get("awakening_effect", {}).get("accuracy_override", 1.0)))
	return accuracy


# ── Action execution ─────────────────────────────────────────────────

func execute(action: Dictionary) -> Array:
	var actor: BattleUnit = action.actor
	if not actor.is_alive():
		return []
	if action.kind == "brace":
		return _execute_brace(actor)
	return _execute_move(actor, action)


func _execute_brace(actor: BattleUnit) -> Array:
	actor.brace(_brace_extension(actor))
	var events: Array = [
		{"type": "action_start", "actor": actor, "label": "Brace"},
		{"type": "brace", "actor": actor},
		{"type": "crest", "unit": actor, "event": "braced"},
	]
	return events


func _brace_extension(actor: BattleUnit) -> int:
	# Iron Tortoise: Brace persists an extra round (entity milestone).
	if actor.entity_passive_type() == "brace_extension":
		return int(actor.entity_passive().get("extra_turns", 1))
	return 0


func _execute_move(actor: BattleUnit, action: Dictionary) -> Array:
	var move: Dictionary = action.move
	var events: Array = []
	var previous_move_id := actor.last_move_id

	if actor.is_move_blocked_by_hex(move):
		actor.note_move_used(move)
		events.append({"type": "blocked", "actor": actor, "move_name": move.get("name", "?"), "reason": "Hex"})
		return events

	# Retarget if the chosen target already fell this round.
	var target: BattleUnit = action.target
	if target == null or not target.is_alive():
		var pool := runtime.living("enemy" if actor.team == "player" else "player")
		if pool.is_empty():
			return events
		target = pool[rng.randi_range(0, pool.size() - 1)]
		events.append({"type": "retarget", "actor": actor, "target": target})

	actor.note_move_used(move)
	events.append({"type": "action_start", "actor": actor, "target": target, "label": move.get("name", "?")})

	# Semantic crest events available regardless of hit outcome.
	if actor.hp_ratio() < 0.5:
		events.append({"type": "crest", "unit": actor, "event": "low_hp_action"})
	if previous_move_id != "" and previous_move_id != actor.move_id_of(move):
		events.append({"type": "crest", "unit": actor, "event": "varied_move"})
	if move.get("slot", "") == "gambit":
		events.append({"type": "crest", "unit": actor, "event": "gambit_used"})

	if rng.randf() >= accuracy_of(actor, move):
		events.append({"type": "miss", "actor": actor, "target": target, "move_name": move.get("name", "?")})
		return events

	target = _apply_interception(actor, move, target, events)

	var was_debuffed := target.has_debuff()
	var estimate := damage_range(actor, target, move, previous_move_id)
	var damage := rng.randi_range(estimate.x, estimate.y)
	target.take_damage(damage)
	events.append({
		"type": "damage", "actor": actor, "target": target,
		"amount": damage, "move_name": move.get("name", "?"),
		"ko": not target.is_alive(),
	})

	# Crest resonance events from a landed hit.
	events.append({"type": "crest", "unit": actor, "event": "hit_landed"})
	events.append({"type": "crest", "unit": target, "event": "damage_taken"})
	if move.get("slot", "") == "gambit":
		actor.gambits_landed += 1
		events.append({"type": "crest", "unit": actor, "event": "gambit_hit"})
	if resolve_move_type(move, actor, target) == "magical":
		events.append({"type": "crest", "unit": actor, "event": "magical_hit"})
	if was_debuffed:
		events.append({"type": "crest", "unit": actor, "event": "hit_debuffed_target"})
	if target.has_status("hexed"):
		events.append({"type": "crest", "unit": actor, "event": "hit_hexed_target"})

	# Crimson awakening: the empowered Gambit steals life.
	if move.get("slot", "") == "gambit" and actor.awakening_effect_active("empowered_gambit"):
		var steal := int(damage * float(actor.crest_record.get("awakening_effect", {}).get("lifesteal", 0.0)))
		if steal > 0:
			actor.heal(steal)
			events.append({"type": "lifesteal", "actor": actor, "amount": steal})

	# Azure awakening: counter stance reflects part of the damage.
	if target.is_alive() and target.awakening_effect_active("counter_stance"):
		var reflected := maxi(1, floori(damage * float(target.crest_record.get("awakening_effect", {}).get("counter_damage", 0.0))))
		actor.take_damage(reflected)
		events.append({
			"type": "counter", "actor": target, "target": actor,
			"amount": reflected, "ko": not actor.is_alive(),
		})

	var decay := runtime.stat_mod_duration(int(game_data.config_value("stat_decay_duration")))
	for mod in move.get("target_stat_mods", []):
		target.apply_stat_mod(mod.stat, int(mod.amount), decay)
		if int(mod.amount) < 0:
			actor.debuffs_applied += 1
		events.append({"type": "stat_mod", "target": target, "stat": mod.stat, "amount": int(mod.amount)})
	# Hex prevents a unit from strengthening itself (1v1 engine parity).
	if not (move.get("self_stat_mods", []).size() > 0 and actor.has_status("hexed")):
		for mod in move.get("self_stat_mods", []):
			actor.apply_stat_mod(mod.stat, int(mod.amount), decay)
			events.append({"type": "stat_mod", "target": actor, "stat": mod.stat, "amount": int(mod.amount)})

	for effect in move.get("status_effects", []):
		var duration := int(effect.get("duration", 1)) + actor.status_duration_bonus()
		target.apply_status(effect.get("status", ""), duration)
		actor.statuses_applied += 1
		events.append({"type": "status", "target": target, "status": effect.get("status", "")})
		events.append({"type": "crest", "unit": actor, "event": "status_applied"})
		# Eclipse awakening: Hex also disturbs the target's cooldowns.
		if actor.awakening_effect_active("hex_saturation"):
			for move_id in target.cooldowns:
				target.cooldowns[move_id] = int(target.cooldowns[move_id]) \
					+ int(actor.crest_record.get("awakening_effect", {}).get("cooldown_penalty", 1))

	return events


func _apply_interception(actor: BattleUnit, move: Dictionary, target: BattleUnit, events: Array) -> BattleUnit:
	## Storm Lion: a teammate's entity may take the hit instead
	## (entity milestone; inert until a unit carries such an entity).
	for ally in runtime.living(target.team):
		if ally == target or not ally.is_alive():
			continue
		if ally.entity_passive_type() != "intercept_adjacent":
			continue
		var chance := float(ally.entity_passive().get("chance", 0.0))
		if rng.randf() < chance:
			events.append({"type": "intercept", "protector": ally, "original_target": target})
			events.append({"type": "crest", "unit": ally, "event": "ally_protected"})
			return ally
	return target


# ── Round end ────────────────────────────────────────────────────────

func end_round() -> void:
	for unit in runtime.all_units():
		if unit.is_alive():
			unit.on_round_end()
	runtime.round_number += 1
