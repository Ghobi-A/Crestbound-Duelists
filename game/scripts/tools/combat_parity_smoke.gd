extends SceneTree
## Compare actual Python damage/effect outcomes with the playable Godot runtime.
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
	print("COMBAT_PARITY: %d damage cases, %d failures" % [cases.damage.size(), failures])
	quit(0 if failures == 0 else 1)
