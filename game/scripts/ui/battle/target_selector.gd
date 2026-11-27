extends RefCounted
class_name TargetSelector
## Tracks the current target choice among living opposing Duelists and
## produces the estimate text for the HUD. Purely stateful — visuals
## are drawn by the controller/HUD.

var targets: Array = []
var index := 0


func open(attacker: BattleUnit, runtime: EncounterRuntime) -> bool:
	targets = runtime.living("enemy" if attacker.team == "player" else "player")
	index = 0
	return not targets.is_empty()


func open_allies(actor: BattleUnit, runtime: EncounterRuntime, fallen := false) -> bool:
	## Item targets: living allies, or the fallen for a revive.
	var side: Array = runtime.player_units if actor.team == "player" else runtime.enemy_units
	targets = side.filter(func(u): return u.is_alive() != fallen)
	index = maxi(0, targets.find(actor))
	return not targets.is_empty()


func cycle(delta: int) -> void:
	if not targets.is_empty():
		index = wrapi(index + delta, 0, targets.size())


func current() -> BattleUnit:
	return null if targets.is_empty() else targets[index]


func estimate_text(attacker: BattleUnit, move: Dictionary, resolver: BattleResolver) -> String:
	var target := current()
	if target == null:
		return ""
	var estimate := resolver.damage_range(attacker, target, move, attacker.last_move_id)
	var accuracy := resolver.accuracy_of(attacker, move)
	var lines: Array[String] = []
	# The violet panel already reads as target info; the name gets the whole line.
	lines.append(target.display_name)
	lines.append("%s  HP %d/%d" % [target.class_record.get("name", ""), target.hp, target.max_hp])
	lines.append("Damage %d-%d   Hit %d%%" % [estimate.x, estimate.y, roundi(accuracy * 100)])
	var extras: Array[String] = []
	for mod in move.get("target_stat_mods", []):
		extras.append("%s%+d" % [str(mod.stat).to_upper(), int(mod.amount)])
	for effect in move.get("status_effects", []):
		extras.append(str(effect.get("status", "")).to_upper())
	# Affinity: a weakness hits harder and staggers; a resistance softens it.
	match resolver.affinity_of(target, move):
		"weak": extras.push_front("WEAK %s" % str(move.get("property", "")).to_upper())
		"resist": extras.push_front("RESISTS %s" % str(move.get("property", "")).to_upper())
	if target.is_braced():
		extras.append("BRACED")
	if not extras.is_empty():
		lines.append(" ".join(extras))
	return "\n".join(lines)
