extends RefCounted
class_name EnemyAI
## Enemy decisions by behaviour profile (combat_config.yaml ai_profiles):
## aggressive, defensive, disruptive, opportunistic, boss, and "legacy"
## (the original greedy policy). Bosses follow their phase's rotation;
## telegraphed moves wind up for a round and release the next. Works for
## any party size. Mirrors party_combat.choose_action exactly, including
## every seeded noise draw, so recorded battles replay identically.


static func profile(unit: BattleUnit, game_data: Node) -> Dictionary:
	var profiles: Dictionary = game_data.config_dict("ai_profiles")
	return profiles.get(unit.ai_profile, profiles.get("legacy", {}))


static func choose_action(unit: BattleUnit, resolver: BattleResolver, runtime: EncounterRuntime) -> Dictionary:
	if not unit.pending.is_empty():
		if int(unit.pending.due_round) <= runtime.round_number:
			return {"actor": unit, "kind": "move", "move": unit.pending.move, "target": unit.pending.target, "release": true}
		return {"actor": unit, "kind": "hold", "move": {}, "target": null}
	var weights := profile(unit, resolver.game_data)
	if unit.awakening_ready() and int(weights.get("awaken", 1)) > 0:
		return {"actor": unit, "kind": "awaken", "move": {}, "target": null}

	var candidates: Array = unit.moves.filter(func(m): return unit.is_move_available(m))
	if unit.forced_move != "":
		var wanted := unit.forced_move
		var forced := candidates.filter(func(m): return unit.move_id_of(m) == wanted)
		unit.forced_move = ""
		if not forced.is_empty():
			candidates = forced
	elif not unit.rotation.is_empty():
		var step: Dictionary = unit.rotation[unit.rotation_index % unit.rotation.size()]
		unit.rotation_index += 1
		var ids: Array = [step.move] if step.has("move") else step.get("pick", [])
		var narrowed := candidates.filter(func(m): return ids.has(unit.move_id_of(m)))
		if not narrowed.is_empty():
			candidates = narrowed

	var targets := runtime.living(runtime.opposing(unit.team))
	var best_score := -1.0
	var best := {"actor": unit, "kind": "brace", "move": {}, "target": null}
	var brace_below := float(weights.get("brace_below_hp", 0.0))
	if brace_below > 0.0 and unit.hp_ratio() < brace_below:
		best_score = float(weights.get("brace_value", 0.0))
	var noise := float(weights.get("noise", 0.0))
	for move in candidates:
		var rule := str(move.get("target_rule", "enemy"))
		if rule == "all_enemies":
			var total := 0.0
			for target in targets:
				total += _score(unit, move, target, resolver, weights)
			if noise > 0.0:
				total += resolver.dice.roll() * noise
			if total > best_score:
				best_score = total
				best = {"actor": unit, "kind": "move", "move": move, "target": targets[0] if not targets.is_empty() else null}
			continue
		if rule == "self":
			var own := float(weights.get("self_move", 6.0))
			if noise > 0.0:
				own += resolver.dice.roll() * noise
			if own > best_score:
				best_score = own
				best = {"actor": unit, "kind": "move", "move": move, "target": unit}
			continue
		for target in targets:
			var score := _score(unit, move, target, resolver, weights)
			if noise > 0.0:
				score += resolver.dice.roll() * noise
			if score > best_score:
				best_score = score
				best = {"actor": unit, "kind": "move", "move": move, "target": target}
	if best.kind == "move" and bool(best.move.get("telegraph", false)):
		best.kind = "windup"
	return best


static func _score(unit: BattleUnit, move: Dictionary, target: BattleUnit, resolver: BattleResolver, weights: Dictionary) -> float:
	var estimate := resolver.damage_range(unit, target, move, unit.last_move_id)
	var low := estimate.x
	var high := estimate.y
	if int(move.get("power", 0)) <= 0:
		low = 0
		high = 0
	var accuracy := resolver.accuracy_of(unit, move)
	var mid := (low + high) / 2.0
	var score := mid * accuracy * float(weights.get("damage", 1.0))
	# Finish wounded targets.
	if high >= target.hp and int(move.get("power", 0)) > 0:
		score += float(weights.get("ko", 0.0)) * accuracy
	# Value applying statuses to targets that don't have them yet.
	for effect in move.get("status_effects", []):
		if str(effect.get("target", "enemy")) == "enemy" and not target.has_status(str(effect.get("status", ""))):
			score += float(weights.get("status", 0.0))
	# Value fresh debuffs.
	for mod in move.get("target_stat_mods", []):
		if int(mod.amount) < 0 and not target.has_debuff():
			score += float(weights.get("debuff", 0.0))
	# Discourage risky self-weakening when already wounded.
	if unit.hp_ratio() < float(weights.get("self_risk_hp", 0.0)):
		for mod in move.get("self_stat_mods", []):
			if int(mod.amount) < 0:
				score -= float(weights.get("self_risk", 0.0))
	score += float(weights.get("finisher", 0.0)) * (1.0 - target.hp_ratio())
	if target.has_status("exposed") or target.staggered:
		score += float(weights.get("exposed", 0.0))
	score += float(weights.get("target_resonance", 0.0)) * target.resonance
	if move.get("tags", []).has("guard_break") and target.brace_streak >= 2:
		score += float(weights.get("punish_brace", 0.0))
	if target.tags.has("protected"):
		score += float(weights.get("target_protected", 0.0))
	if bool(move.get("dispel_buffs", false)) and target.stat_mods.any(func(m): return int(m.amount) > 0):
		score += float(weights.get("dispel", 0.0))
	return score
