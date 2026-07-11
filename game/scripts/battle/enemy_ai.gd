extends RefCounted
class_name EnemyAI
## Heuristic action selection for enemy Duelists — a greedy policy in
## the spirit of the Balance Lab's greedy AI, extended with kill
## detection, Hex value, and a defensive fallback. Works for any party
## size (1v1 through 3v3 and asymmetric encounters).

const KO_BONUS := 1000.0
const STATUS_VALUE := 8.0
const DEBUFF_VALUE := 4.0


static func choose_action(unit: BattleUnit, resolver: BattleResolver, runtime: EncounterRuntime) -> Dictionary:
	var targets := runtime.living("player" if unit.team == "enemy" else "enemy")
	var best_score := -1.0
	var best_action := {"actor": unit, "kind": "brace", "move": {}, "target": null}

	for move in unit.moves:
		if not unit.is_move_available(move):
			continue
		for target in targets:
			var score := _score(unit, move, target, resolver)
			if score > best_score:
				best_score = score
				best_action = {"actor": unit, "kind": "move", "move": move, "target": target}
	return best_action


static func _score(unit: BattleUnit, move: Dictionary, target: BattleUnit, resolver: BattleResolver) -> float:
	var estimate := resolver.damage_range(unit, target, move, unit.last_move_id)
	var accuracy := resolver.accuracy_of(unit, move)
	var mid := (estimate.x + estimate.y) / 2.0
	var score := mid * accuracy

	# Finish wounded targets.
	if estimate.y >= target.hp:
		score += KO_BONUS * accuracy

	# Value applying statuses (Hex) to targets that don't have them yet.
	for effect in move.get("status_effects", []):
		if not target.has_status(effect.get("status", "")):
			score += STATUS_VALUE

	# Value fresh debuffs slightly.
	for mod in move.get("target_stat_mods", []):
		if int(mod.amount) < 0 and not target.has_debuff():
			score += DEBUFF_VALUE

	# Discourage risky self-weakening when already wounded.
	if unit.hp_ratio() < 0.35:
		for mod in move.get("self_stat_mods", []):
			if int(mod.amount) < 0:
				score -= 6.0
	return score
