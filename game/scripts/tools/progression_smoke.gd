extends Node
## Progression, rewards and saves through the real autoloads: the story
## roster, cast builds, loadouts, charms, move unlocks, quests derived
## from flags, one-time rewards, saves v3 (round trip and v2 migration),
## Quick Battle never saving, retry snapshots, battle results by member
## id, encounter parties from data, and the Item command in battle.

var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _ready() -> void:
	await get_tree().process_frame
	check_story_roster()
	check_loadouts_and_charms()
	check_quests_and_rewards()
	check_saves()
	check_battle_bookkeeping()
	check_item_command()
	print("PROGRESSION_SMOKE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func check_story_roster() -> void:
	GameState.start_story()
	check(GameState.mode == "story" and GameState.story_stage == "morning", "story starts in the morning")
	check(GameState.party.size() == 1 and GameState.party[0].id == "kai", "story starts with Kai alone")
	var build := GameState.member_build(GameState.member("kai"))
	check(build.get("move_ids", []) == ["kai_strike", "shoulder_check", "wild_swing"], "Kai starts Unbonded")
	check(str(build.get("crest_id", "")) == "" and GameState.member_max_hp(GameState.member("kai")) == 92, "Unbonded Kai has no Crest, 92 HP")
	GameState.set_kai_profile("kai_unsettled")
	build = GameState.member_build(GameState.member("kai"))
	check(str(build.crest_id) == "unsettled_crest" and build.move_ids.has("crest_flare"), "the bond gives Kai the Unsettled kit")
	GameState.stabilise_class("guardian")
	build = GameState.member_build(GameState.member("kai"))
	check(str(build.class_id) == "guardian" and str(build.crest_id) == "azure_crest" and GameState.has_flag("class_stabilised"), "Civara stabilises the class")
	check(build.move_ids == GameData.get_class_record("guardian").move_ids, "the stabilised class equips its default kit")
	var almyra := GameState.add_member("almyra", "almyra")
	check(GameState.member_build(almyra).get("entity_id", "") == "storm_lion", "companions come from cast builds")
	GameState.remove_member("almyra")
	check(GameState.member("almyra").is_empty(), "companions can leave")


func check_loadouts_and_charms() -> void:
	GameState.start_story()
	check(not GameState.set_loadout("kai", ["steady_footing"]), "locked moves cannot be equipped")
	var lines := GameState.apply_rewards({"unlocks": ["steady_footing"], "equipment": ["greymaw_fang"], "crowns": 5, "items": {"potion": 2}})
	check(lines.size() == 4, "reward lines for each kind: %s" % str(lines))
	check(GameState.crowns == GameState.STARTING_CROWNS + 5 and int(GameState.inventory.potion) == 2, "crowns and items granted")
	check(GameState.set_loadout("kai", ["kai_strike", "shoulder_check", "wild_swing", "steady_footing"]), "four-move loadout with the Flex slot")
	check(not GameState.set_loadout("kai", ["kai_strike", "shoulder_check", "wild_swing", "steady_footing", "kai_strike"]), "no more than four moves")
	check(GameState.equip("kai", "greymaw_fang"), "owned charm equips")
	check(not GameState.equip("kai", "road_charm"), "unowned charm refused")
	var unit := BattleUnit.create(GameState.member_build(GameState.member("kai")), "player", GameData)
	check(unit.moves.size() == 4 and unit.brace_pierce_left == 1 and unit.member_id == "kai", "loadout and charm reach the battle unit")


func check_quests_and_rewards() -> void:
	GameState.start_story()
	var quest: Dictionary = GameData.datasets.quests.side_lena_herbs
	check(GameState.quest_state(quest) == "hidden", "side quest hidden until offered")
	GameState.set_flag("lena_herbs_asked")
	check(GameState.quest_state(quest) == "active" and GameState.quest_steps_done(quest) == 0, "quest active once offered")
	var before := GameState.crowns
	GameState.set_flag("herbs_gathered")
	GameState.set_flag("herbs_delivered")
	check(GameState.quest_state(quest) == "complete", "quest completes from its flags")
	check(GameState.crowns == before + 15 and int(GameState.inventory.get("clearwater", 0)) == 2, "quest reward granted")
	GameState.set_flag("herbs_delivered", false)
	GameState.set_flag("herbs_delivered")
	check(GameState.crowns == before + 15, "quest reward granted once")
	var encounter := {"id": "test_fight", "rewards": {"crowns": 10}}
	check(GameState.grant_encounter_rewards(encounter) == ["10 crowns"], "encounter reward lines")
	check(GameState.grant_encounter_rewards(encounter).is_empty(), "one-time encounter reward")
	var repeat := {"id": "test_grass", "rewards": {"crowns": 4, "once": false}}
	GameState.grant_encounter_rewards(repeat)
	check(not GameState.grant_encounter_rewards(repeat).is_empty(), "repeatable encounter reward")


func check_saves() -> void:
	GameState.start_story()
	GameState.apply_rewards({"equipment": ["drowned_bell"], "unlocks": ["steady_footing"]})
	GameState.equip("kai", "drowned_bell")
	GameState.set_flag("goats_rounded")
	GameState.set_checkpoint("kai_house", "bed")
	check(SaveManager.save_game(), "story saves")
	GameState.start_story()
	check(SaveManager.load_game(), "save v3 loads")
	var kai := GameState.member("kai")
	check(str(kai.equipment) == "drowned_bell" and kai.unlocked_moves.has("steady_footing"), "charm and unlocks persist")
	check(GameState.has_flag("goats_rounded") and GameState.checkpoint.get("spawn", "") == "bed", "flags and checkpoint persist")
	check(GameState.story_stage == "morning" and GameState.equipment_owned == ["drowned_bell"], "stage and owned charms persist")
	# Quick Battle never writes the story save.
	var file_before := FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	GameState.start_quick_battle("warrior")
	check(not SaveManager.save_game(), "Quick Battle does not save")
	check(FileAccess.get_file_as_string(SaveManager.SAVE_PATH) == file_before, "story save untouched by Quick Battle")
	# A v2 save from the class-first prototype restarts the chapter, keeping coin.
	var legacy := {"save_version": 2, "state": {"player_class_id": "mage", "crowns": 140, "inventory": {"potion": 3},
		"party": [{"name": "Kai", "class_id": "mage"}], "flags": {"hollow_court_cleared": true}}}
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(SaveManager.load_game(), "v2 save migrates")
	check(GameState.crowns == 140 and int(GameState.inventory.get("potion", 0)) == 3, "migration keeps crowns and items")
	check(GameState.has_flag("legacy_save_migrated") and not GameState.has_flag("hollow_court_cleared"), "migration restarts the story")
	check(GameState.member("kai").get("cast", "") == "kai_unbonded" and GameState.mode == "story", "migrated save starts Unbonded in story mode")


func check_battle_bookkeeping() -> void:
	GameState.start_story()
	GameState.inventory = {"potion": 2}
	GameState.member("kai")["current_hp"] = 50
	GameState.snapshot_for_retry()
	var encounter := {"id": "test", "objective": "defeat_all", "player_party": ["kai", "joey"], "enemy_party": [GameState.cast_build("riven_wisp")]}
	var builds := GameState.encounter_party(encounter)
	check(builds.size() == 2 and builds[0].id == "kai" and builds[1].get("tags", []).has("protected"), "authored player_party resolves roster and cast ids")
	var runtime := EncounterRuntime.from_data(encounter, builds, GameData, GameState.inventory)
	runtime.player_units[0].hp = 30
	runtime.inventory["potion"] = 1
	GameState.store_battle_results(runtime.player_units, runtime.inventory)
	check(int(GameState.member("kai").current_hp) == 30 and int(GameState.inventory.potion) == 1, "battle results stored by member id")
	check(GameState.member("joey").is_empty(), "guests do not join the roster")
	GameState.restore_retry_snapshot()
	check(int(GameState.member("kai").current_hp) == 50 and int(GameState.inventory.potion) == 2, "retry restores HP and items")
	GameState.recover_party()
	check(not GameState.member("kai").has("current_hp"), "recovery point restores full HP")


func check_item_command() -> void:
	var encounter := {"id": "test", "objective": "defeat_all", "enemy_party": [GameState.cast_build("riven_wisp")]}
	var kai := GameState.cast_build("kai_unbonded")
	kai["current_hp"] = 40
	var runtime := EncounterRuntime.from_data(encounter, [kai], GameData, {"potion": 1, "smelling_salts": 1})
	var resolver := BattleResolver.new(runtime, GameData, BattleDice.seeded(3))
	var unit: BattleUnit = runtime.player_units[0]
	var events := resolver.execute({"actor": unit, "kind": "item", "move": {}, "target": unit, "item_id": "potion"})
	check(unit.hp == 65 and int(runtime.inventory.potion) == 0, "Potion heals 25 in battle and is spent")
	check(events.any(func(e): return e.type == "heal"), "heal event")
	events = resolver.execute({"actor": unit, "kind": "item", "move": {}, "target": unit, "item_id": "potion"})
	check(events.any(func(e): return e.type == "fizzle"), "no Potion left: the action fizzles")
	check(ActionMenu.usable_items({"potion": 0, "resonance_tonic": 1, "smelling_salts": 1}).map(func(i): return i.id) == ["resonance_tonic", "smelling_salts"], "the bag lists battle-usable items in stock")
