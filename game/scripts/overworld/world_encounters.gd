extends RefCounted
class_name WorldEncounters
## Map-independent rules; called once per completed movement step.

static func sees_player(origin: Vector2i, facing: Vector2i, target: Vector2i, distance: int, walkable: Callable) -> bool:
	if facing.length_squared() != 1: return false
	for step in range(1, distance + 1):
		var tile := origin + facing * step
		if not walkable.call(tile): return false
		if tile == target: return true
	return false

static func roll_step(symbol: String, zones: Array, state: Dictionary, rng: RandomNumberGenerator) -> String:
	# Cooldown counts actual travel steps, including safe terrain. It is saved.
	if int(state.get("cooldown", 0)) > 0:
		state.cooldown = int(state.cooldown) - 1
		return ""
	for zone in zones:
		if symbol != str(zone.symbol): continue
		if rng.randf() >= float(zone.probability): return ""
		var pool: Array = zone.encounters
		if pool.is_empty(): return ""
		state.cooldown = int(zone.cooldown_steps)
		return str(pool[rng.randi_range(0, pool.size()-1)])
	return ""
