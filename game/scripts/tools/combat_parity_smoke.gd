extends SceneTree
## Compare actual Python damage/effect outcomes with the playable Godot runtime.
##
## Two fixtures from tools/generate_combat_parity.py:
##   combat_parity_cases.json  classic damage bounds per class pair, move
##                             and Brace state, plus Hex and refresh checks;
##   combat_replays.json       whole seeded party battles from
##                             party_combat.py, replayed here command by
##                             command and dice draw by dice draw. The
##                             canonical event log must match exactly.
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func make_unit(id: String, data: Node, team: String) -> BattleUnit:
	return BattleUnit.create({"name":id, "class_id":id, "position":"front", "crest_id":"", "entity_id":""}, team, data)

func run_checks() -> void:
	var data := root.get_node("GameData")
	var cases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_parity_cases.json"))
	var runtime := EncounterRuntime.new()
	var resolver := BattleResolver.new(runtime, data)
	for item in cases.damage:
		var actor := make_unit(str(item.actor), data, "player")
		var target := make_unit(str(item.target), data, "enemy")
		if item.braced: target.brace()
		var bounds := resolver.damage_range(actor, target, actor.moves[int(item.move)])
		check(bounds == Vector2i(int(item.bounds[0]),int(item.bounds[1])), "Damage mismatch: " + str(item))
	var neutral := make_unit("neutral", data, "player")
	var sorcerer := make_unit("sorcerer", data, "enemy")
	runtime.player_units = [neutral]
	runtime.enemy_units = [sorcerer]
	neutral.apply_status("hexed", 2)
	resolver._execute_move(neutral, {"actor":neutral, "move":neutral.moves[1], "target":sorcerer, "kind":"move"})
	for i in 4:
		check(neutral.stat(["atk","mag","def","res"][i]) == int(cases.hex_stats[i]), "Hex tradeoff mismatch")
	var guardian := make_unit("guardian", data, "player")
	guardian.apply_stat_mod("def", 8, 4)
	guardian.stat_mods[0].turns -= 1
	guardian.apply_stat_mod("def", 8, 4)
	check(guardian.stat("def") == int(cases.refresh.value), "Refresh value mismatch")
	check(guardian.stat_mods.size() == int(cases.refresh.count) and int(guardian.stat_mods[0].turns) == int(cases.refresh.turns), "Refresh count/duration mismatch")
	var replays := run_replays(data)
	print("COMBAT_PARITY: %d damage cases, %d replays, %d failures" % [cases.damage.size(), replays, failures])
	quit(0 if failures == 0 else 1)


func action_of(command: Dictionary, unit: BattleUnit, runtime: EncounterRuntime) -> Dictionary:
	var move: Dictionary = {}
	for candidate in unit.moves:
		if unit.move_id_of(candidate) == str(command.get("move", "")):
			move = candidate
	var target: BattleUnit = null
	for candidate in runtime.all_units():
		if candidate.ref() == str(command.get("target", "")):
			target = candidate
	var action := {"actor": unit, "kind": str(command.kind), "move": move, "target": target}
	if command.has("item_id"):
		action["item_id"] = str(command.item_id)
	return action


func run_replays(data: Node) -> int:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_replays.json"))
	var played := 0
	for scenario in fixture.scenarios:
		played += 1
		var runtime := EncounterRuntime.from_data(scenario.encounter, scenario.players, data, scenario.inventory)
		var dice := BattleDice.replay(scenario.dice)
		var resolver := BattleResolver.new(runtime, data, dice)
		var log: Array = []
		var diverged := false
		for commands in scenario.commands:
			var living := runtime.living("player")
			if living.size() != commands.size() or runtime.outcome() != "":
				# The battle already went another way; the log comparison below
				# reports where.
				diverged = true
				break
			var actions: Array = []
			for i in commands.size():
				actions.append(action_of(commands[i], living[i], runtime))
			actions.append_array(resolver.plan_enemy_actions())
			for action in resolver.order_actions(actions):
				if runtime.outcome() != "":
					break
				if not action.actor.is_alive():
					continue
				for event in resolver.execute(action):
					log.append(BattleResolver.canonical(event))
			for event in resolver.end_round():
				log.append(BattleResolver.canonical(event))
		var expected: Array = scenario.log
		var first := -1
		for i in maxi(log.size(), expected.size()):
			if i >= log.size() or i >= expected.size() or str(log[i]) != str(expected[i]):
				first = i
				break
		if first >= 0:
			check(false, "Replay %s diverges at event %d:\n  python: %s\n  godot:  %s" % [scenario.id, first,
				expected[first] if first < expected.size() else "<end>", log[first] if first < log.size() else "<end>"])
		var outcome := runtime.outcome() if runtime.outcome() != "" else "timeout"
		check(outcome == str(scenario.outcome), "Replay %s outcome %s, expected %s" % [scenario.id, outcome, scenario.outcome])
		check(not diverged, "Replay %s diverged before its last round" % scenario.id)
		check(not dice.exhausted and dice.used() == scenario.dice.size(), "Replay %s used %d of %d dice draws" % [scenario.id, dice.used(), scenario.dice.size()])
	check(played == fixture.scenarios.size() and played > 0, "Only %d of %d replays ran" % [played, fixture.scenarios.size()])
	return played
