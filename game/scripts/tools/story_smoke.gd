extends Node
## Chapter One end to end, headless, through the real autoloads and the real
## story layer: DialogueBox (conversations, choices, show_if variants),
## StoryDirector (effects), WorldCatalog (show_if, triggers) and GameState
## (stages, flags, quests, saves). Battles are taken as won by recording what
## the battle scene records on victory (combat itself is covered by the
## parity replays); scene changes are checked as the requests the story makes.
##
## New Game -> Kai's house -> goats and the spar -> village -> abnormal signs
## -> Almyra's arrival and the cordon -> the incident -> the Hollow Court
## (stair, gallery, chamber, bond, Choir) -> aftermath and the custody
## choice -> Civara, classification and the assessment -> the ending.
## Also: Greymaw's den (present, beaten, gone, persisted), Retry rules and a
## save/load round trip mid-chapter.

var failures: Array[String] = []
var dialogue: DialogueBox
var last_travel := {}


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _ready() -> void:
	await get_tree().process_frame
	await check_real_arrival()
	dialogue = DialogueBox.new()
	add_child(dialogue)
	dialogue.load_file("res://data/dialogue/greymere.json")
	dialogue.merge_file(WorldLocation.CHAPTER_DIALOGUE)
	run_chapter()
	check_greymaw_and_retry()
	check_quick_battle()
	print("STORY_SMOKE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func check_real_arrival() -> void:
	## The real scenes: New Game opens Kai's house and its arrival beat plays
	## once the fade has finished (a trigger must not be lost to the fade),
	## and Kai stands on the map in his village clothes.
	get_tree().current_scene = null
	Engine.time_scale = 10
	GameState.start_story()
	SceneTransition.change_scene(GameState.current_scene)
	var house: WorldLocation = null
	for _frame in 600:
		await get_tree().process_frame
		house = get_tree().current_scene as WorldLocation
		if house != null and not SceneTransition._busy and house._dialogue.active:
			break
	check(house != null and house.location_id == "kai_house", "New Game loads Kai's house")
	if house == null:
		return
	check(house._dialogue.active and house._dialogue._current_key == "morning_wake", "the wake-up scene plays on arrival")
	check(house._player.tile == WorldCatalog.tile(WorldCatalog.location("kai_house").spawn_points.bed.tile), "Kai wakes by his bed")
	check(house._player._has_sheet, "Kai has a map sprite before he has a class")
	while house._dialogue.active:
		house._dialogue.complete_reveal()
		house._dialogue.confirm()
	check_pause_menu(house)
	Engine.time_scale = 1
	get_tree().current_scene = null
	house.queue_free()
	await get_tree().process_frame


func press(node: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	node._unhandled_input(event)


func check_pause_menu(house: WorldLocation) -> void:
	## The field menu on the real scene: it opens on Back, blocks the field,
	## swaps a move in the loadout, changes a volume, and closes.
	press(house, "cancel")
	var menu := house._pause
	check(menu.visible and house._menu_open and house.movement_blocked(), "Back opens the field menu over a frozen field")
	for tab_name in PauseMenu.TABS:
		menu.select_tab(tab_name)
		menu._page.queue_redraw()
	check(menu.current_tab() == "Title", "every tab can be shown")
	GameState.unlock_move("kai", "steady_footing")
	menu.select_tab("Abilities")
	press(menu, "interact")
	var before: Array = GameState.equipped_moves(GameState.member("kai")).duplicate()
	press(menu, "move_right")
	var after: Array = GameState.equipped_moves(GameState.member("kai"))
	check(after != before and after.has("steady_footing"), "Abilities swaps an unlocked move into the loadout")
	press(menu, "cancel")
	menu.select_tab("Settings")
	press(menu, "interact")
	var level := AudioSettings.level("Master")
	press(menu, "move_left")
	check(AudioSettings.level("Master") == level - 1, "Settings lowers the master volume")
	press(menu, "move_right")
	check(AudioSettings.level("Master") == level, "and raises it back")
	press(menu, "cancel")
	press(menu, "cancel")
	check(not menu.visible and not house._menu_open, "Back closes the menu")


# ── Helpers ──────────────────────────────────────────────────────────

func talk(key: String, choices: Array = []) -> Dictionary:
	## Plays a conversation to the end, answering choices in order (first
	## option when none is given). Returns the deferred story effects.
	check(dialogue.has_key(key), "conversation exists: " + key)
	dialogue.play(key)
	var guard := 0
	while dialogue.active and guard < 500:
		guard += 1
		if dialogue.is_choosing():
			dialogue.choose(int(choices.pop_front()) if not choices.is_empty() else 0)
		else:
			dialogue.complete_reveal()
			dialogue.confirm()
	check(not dialogue.active, "conversation ends: " + key)
	return StoryDirector.take_pending()


func arrive(location_id: String, tile := Vector2i(-1, -1)) -> String:
	## The trigger WorldLocation would play on arriving (no tile) or on
	## stepping onto `tile`; "" when none fires. Records one-shot triggers.
	GameState.location_id = location_id
	for trigger in WorldCatalog.location(location_id).get("triggers", []):
		var once := bool(trigger.get("once", true))
		if once and GameState.has_flag("seen_" + str(trigger.id)):
			continue
		if not WorldCatalog.present(trigger):
			continue
		var area: Array = trigger.get("area", [])
		if area.is_empty() != (tile == Vector2i(-1, -1)):
			continue
		if not area.is_empty() and not Rect2i(int(area[0]), int(area[1]), int(area[2]), int(area[3])).has_point(tile):
			continue
		if once:
			GameState.set_flag("seen_" + str(trigger.id))
		return str(trigger.dialogue)
	return ""


func play_arrival(location_id: String, expected: String, choices: Array = [], tile := Vector2i(-1, -1)) -> Dictionary:
	var key := arrive(location_id, tile)
	check(key == expected, "%s plays %s (got '%s')" % [location_id, expected, key])
	return talk(key, choices) if key != "" else {}


func win(encounter_id: String, trainer_id := "") -> void:
	## What BattleController records on a victory.
	var encounter := GameData.get_encounter(encounter_id)
	check(not encounter.is_empty(), "encounter exists: " + encounter_id)
	GameState.grant_encounter_rewards(encounter)
	GameState.set_flag(encounter_id + "_won")
	if trainer_id != "":
		GameState.set_flag(trainer_id + "_defeated")
	for flag in encounter.get("return", {}).get("flags", []):
		GameState.set_flag(str(flag))


func expect_battle(next: Dictionary, encounter_id: String) -> void:
	check(str(next.get("battle", "")) == encounter_id, "story starts battle %s (got %s)" % [encounter_id, str(next)])


func npc(location_id: String, name: String) -> Dictionary:
	for resident in WorldCatalog.location(location_id).get("npcs", []):
		if str(resident.name) == name and WorldCatalog.present(resident):
			return resident
	return {}


func stage(expected: String) -> void:
	check(GameState.story_stage == expected, "stage is %s (got %s)" % [expected, GameState.story_stage])


# ── The chapter ──────────────────────────────────────────────────────

func run_chapter() -> void:
	GameState.start_story()
	check(GameState.current_scene.ends_with("kai_house.tscn") and GameState.location_spawn == "bed", "New Game wakes Kai at home")
	check(WorldCatalog.location("kai_house").spawn_points.has("bed"), "Kai's house has a bed spawn")
	check(GameState.player_class_id == "" and GameState.member_build(GameState.member("kai")).get("crest_id", "") == "", "no class or Crest before Civara")
	play_arrival("kai_house", "morning_wake")
	talk("kai_note")
	check(GameState.has_flag("read_lena_note"), "Lena's note")
	# The south road waits for Danfor's lesson.
	var road: Dictionary = WorldCatalog.location("greymere").exits[0]
	check(not WorldCatalog.present(road), "south road closed in the morning")
	check(arrive("greymere") == "", "nothing fires on entering town in the morning")
	check(arrive("greymere", Vector2i(17, 31)) == "south_road_closed", "Danfor turns Kai back at the south road")
	check(npc("greymere", "Liora Sen").is_empty() and npc("inn", "Joey").is_empty(), "Liora is not in Greymere; Joey is not duplicated")
	# Joey's goats, then Danfor's lesson.
	expect_battle(talk("joey_talk"), "greymere_spar_danfor")
	check(GameState.has_flag("goats_rounded"), "goats rounded up")
	win("greymere_spar_danfor")
	play_arrival("greymere", "after_spar")
	stage("village")
	check(WorldCatalog.present(road), "south road opens after the lesson")
	# The village round.
	talk("gell_talk", [1])
	check(GameState.has_flag("talked_gell_story") and GameState.has_flag("gell_crates_asked"), "Gell's account and his favour")
	talk("lena_talk")
	check(GameState.has_flag("talked_lena_story") and GameState.has_flag("lena_herbs_asked"), "Lena patches the scrape")
	talk("silas_talk", [0])
	check(GameState.has_flag("talked_silas_ridge"), "Silas's question")
	talk("ferris_talk")
	check(GameState.has_flag("ferris_rumour_heard"), "Ferris's rumour")
	check(GameState.quest_state(GameData.datasets.quests.main_greymere_day) == "complete", "A Day in Greymere complete")
	# Side quests resolve from flags.
	GameState.set_flag("herbs_gathered")
	talk("lena_talk")
	check(GameState.has_flag("herbs_delivered"), "herbs delivered")
	GameState.set_flag("crates_picked")
	talk("senna_talk")
	check(GameState.has_flag("crates_delivered"), "lamp oil delivered")
	talk("joey_talk")
	check(GameState.has_flag("joey_wager_offered"), "Joey's wager offered")
	win("route01_rowan", "route01_rowan")
	win("route01_challenger", "route01_challenger")
	expect_battle(talk("joey_talk"), "joey_wager")
	win("joey_wager")
	for quest in ["side_lena_herbs", "side_gell_crates", "side_joey_wager"]:
		check(GameState.quest_state(GameData.datasets.quests[quest]) == "complete", quest + " complete")
	# Abnormal signs, Almyra's arrival and the cordon.
	play_arrival("greymere", "abnormal_signs")
	stage("abnormal")
	check(arrive("greymere") == "", "Almyra waits for the square, not the gate")
	talk(arrive("greymere", Vector2i(17, 15)))
	stage("cordon")
	check(GameState.has_flag("almyra_arrived") and GameState.has_flag("cordon_up"), "inspection and cordon")
	check(not npc("greymere", "Warden Almyra").is_empty() and not npc("greymere", "Specialist Hale").is_empty(), "the inspection party at the arch")
	# Save mid-chapter and load it back.
	var saved := GameState.to_save_dict()
	GameState.start_story()
	GameState.from_save_dict(saved)
	stage("cordon")
	check(GameState.has_flag("joey_wager_won") and GameState.member("kai").cast == "kai_unbonded", "the save keeps flags and Kai's kit")
	# The incident.
	var next := talk("danfor_cordon")
	stage("incident")
	check(next.get("travel", {}).get("location", "") == "court_stair", "Kai goes down after Joey")
	check(npc("greymere", "Danfor").get("dialogue", "") != "danfor_cordon", "the cordon scene does not repeat")
	# The Hollow Court.
	play_arrival("court_stair", "court_stair_arrive")
	check(not npc("court_stair", "Riven Wisp").is_empty(), "a Wisp waits on the stair")
	win("court_stair_wisp", "court_stair_wisp")
	win("court_stair_pair", "court_stair_pair")
	check(npc("court_stair", "Riven Wisp").is_empty() and npc("court_stair", "Riven Wisps").is_empty(), "beaten Riven are gone")
	check(not WorldCatalog.present(WorldCatalog.location("court_gallery").exits[1]), "the far passage is guarded")
	expect_battle(play_arrival("court_gallery", "gallery_almyra", [], Vector2i(22, 5)), "court_gallery_husk")
	win("court_gallery_husk")
	play_arrival("court_gallery", "gallery_almyra_freed")
	check(not GameState.member("almyra").is_empty(), "Almyra joins")
	win("court_gallery_pair", "court_gallery_pair")
	check(WorldCatalog.present(WorldCatalog.location("court_gallery").exits[1]), "the way to the chamber opens")
	expect_battle(play_arrival("court_chamber", "chamber_joey"), "court_protect_joey")
	win("court_protect_joey")
	expect_battle(play_arrival("court_chamber", "chamber_anchor"), "court_anchor")
	win("court_anchor")
	next = play_arrival("court_chamber", "chamber_bond")
	check(str(next.get("cinematic", "")) == "bond_memory", "the bond plays the impossible memory")
	check(FileAccess.file_exists("res://data/cinematics/bond_memory.json"), "bond memory timeline exists")
	check(GameState.has_flag("kai_bonded") and GameState.member("kai").cast == "kai_unsettled", "Kai bonds: the Unsettled Crest")
	check(not npc("court_chamber", "The Sealed Choir").is_empty() and npc("court_chamber", "Riven Anchor").is_empty(), "the Choir rises where the anchor stood")
	expect_battle(play_arrival("court_chamber", "chamber_choir"), "court_sealed_choir")
	win("court_sealed_choir")
	var after: Dictionary = GameData.get_encounter("court_sealed_choir").return
	check(after.location == "greymere" and WorldCatalog.location("greymere").spawn_points.has(str(after.spawn)), "the climax returns to Greymere")
	# Aftermath: the custody conversation, every question, then the choice.
	next = play_arrival("greymere", "aftermath", [0, 1, 2, 3, 0])
	stage("civara")
	check(GameState.has_flag("custody_choice_made"), "Kai chooses classification")
	check(next.get("travel", {}).get("location", "") == "civara_forecourt", "the north road leads to Civara")
	check(npc("greymere", "Warden Almyra").get("dialogue", "") == "almyra_aftermath", "Greymere is in its aftermath")
	# Civara.
	play_arrival("civara_forecourt", "civara_arrive")
	check(GameState.has_flag("arrived_civara") and GameState.checkpoint.get("location", "") == "civara_forecourt", "Civara checkpoint")
	expect_battle(play_arrival("civara_hall", "civara_classification", [2, 0]), "civara_assessment_mage")
	check(GameState.player_class_id == "mage" and GameState.member("kai").sprite_key == "aren/mage", "Kai stabilises the chosen class")
	check(GameState.has_flag("class_mage"), "class flag for the assessor")
	check(arrive("civara_hall") == "civara_assess_retry", "a lost assessment can be taken again")
	win("civara_assessment_mage")
	next = play_arrival("civara_hall", "civara_after")
	stage("complete")
	check(str(next.get("cinematic", "")) == "chapter_one_ending" and str(next.get("scene", "")).ends_with("end_of_demo.tscn"), "the ending, then the end-of-demo screen")
	check(ResourceLoader.exists("res://scenes/ui/end_of_demo.tscn"), "end-of-demo scene exists")
	check(GameState.quest_state(GameData.datasets.quests.main_classification) == "complete", "Classification complete")


func check_greymaw_and_retry() -> void:
	GameState.start_story()
	GameState.advance_stage("village")
	var greymaw := npc("route_01", "Old Greymaw")
	check(not greymaw.is_empty() and greymaw.get("encounter", "") == "greymaw_den", "Old Greymaw waits in the den")
	var den := GameData.get_encounter("greymaw_den")
	check(bool(den.get("retry", false)), "the den fight offers Retry")
	check(not bool(GameData.get_encounter("route01_roadside").get("retry", false)), "roadside fights still send Kai home")
	win("greymaw_den", "greymaw_den")
	check(npc("route_01", "Old Greymaw").is_empty(), "a beaten Greymaw is gone")
	check(GameState.equipment_owned.has("greymaw_fang"), "the Greymaw Fang")
	var saved := GameState.to_save_dict()
	GameState.start_story()
	GameState.from_save_dict(saved)
	check(npc("route_01", "Old Greymaw").is_empty() and GameState.equipment_owned.has("greymaw_fang"), "Greymaw's defeat persists")
	talk("ferris_talk")
	check(GameState.has_flag("greymaw_den_won"), "Ferris hears about it")
	# Unbeaten, Greymaw leaves the chapter once the Court opens.
	GameState.start_story()
	GameState.advance_stage("incident")
	check(npc("route_01", "Old Greymaw").is_empty(), "Greymaw is out of reach after the incident")


func check_quick_battle() -> void:
	## Every class against every challenge builds a real battle from data,
	## with the chosen Entity, and Quick Battle never writes the story save.
	var quick := preload("res://scripts/ui/quick_battle.gd")
	for class_id in quick.CLASSES:
		for challenge in quick.CHALLENGES:
			GameState.start_quick_battle(class_id)
			GameState.member("kai")["entity_id"] = "storm_lion"
			var id := str(challenge[1])
			id = id % class_id if "%s" in id else id
			var encounter := GameData.get_encounter(id)
			check(not encounter.is_empty(), "Quick Battle challenge exists: " + id)
			var builds := GameState.encounter_party(encounter)
			check(builds.size() == int(encounter.player_slots), "Quick Battle party fills %s" % id)
			var runtime := EncounterRuntime.from_data(encounter, builds, GameData, GameState.inventory)
			check(runtime.player_units.size() == builds.size() and not runtime.enemy_units.is_empty(), "Quick Battle builds %s as %s" % [id, class_id])
			check(runtime.player_units[0].entity_id == "storm_lion", "Kai's chosen Entity fights with him")
			check(GameState.mode == "quick" and not SaveManager.save_game(), "Quick Battle never saves")
