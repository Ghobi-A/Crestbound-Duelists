extends SceneTree
## QA probe: measures random-encounter pacing on Route 01 with the real
## roll (WorldEncounters.roll_step) and Godot's RNG. A player walks back and
## forth through tall grass; after each fight the post-battle grace applies,
## as GameState.finish_world_battle does. Prints the steps (and seconds, at
## 0.14 s a step) from arrival to the first fight and between fights.
##
##   godot --headless --path game --script res://scripts/tools/encounter_probe.gd -- <prob> <cooldown> <arrival> <return> [runs] [steps]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var zone := {"symbol": "g", "probability": float(a[0]), "cooldown_steps": int(a[1]), "encounters": ["x"]}
	var arrival := int(a[2])
	var after_battle := int(a[3])
	var runs := int(a[4]) if a.size() > 4 else 50
	var steps := int(a[5]) if a.size() > 5 else 400
	var firsts: Array[int] = []
	var gaps: Array[int] = []
	for run in runs:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1901 + run * 7919
		var state := {"cooldown": arrival}
		var since := 0
		var first := -1
		for step in steps:
			since += 1
			if WorldEncounters.roll_step("g", [zone], state, rng) != "":
				if first < 0: first = since
				else: gaps.append(since)
				since = 0
				state.cooldown = after_battle   # returning from the fight
		if first >= 0: firsts.append(first)
	firsts.sort(); gaps.sort()
	print("ENCOUNTER_PROBE first: median %d steps (%.1f s), min %d | between: median %d steps (%.1f s), min %d, mean %.1f, fights per 100 grass steps %.1f" % [
		firsts[firsts.size() / 2], firsts[firsts.size() / 2] * 0.14, firsts[0],
		gaps[gaps.size() / 2], gaps[gaps.size() / 2] * 0.14, gaps[0],
		gaps.reduce(func(s, v): return s + v, 0) / float(gaps.size()), 100.0 * (gaps.size() + firsts.size()) / (runs * steps)])
	quit()
