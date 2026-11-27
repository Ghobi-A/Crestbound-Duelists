extends Node
## Executes real Godot nodes headlessly. This does NOT certify raster appearance.
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _ready() -> void:
	seed(41)
	await get_tree().process_frame
	check(GameData.load_ok, "GameData failed")
	await check_classes()
	await check_dialogue()
	await check_story_dialogue()
	await check_command_feedback()
	await check_formations()
	await check_enemy_hud()
	await check_world_and_setup()
	await check_battle_flow(false)
	await check_battle_flow(true)
	print("PRESENTATION_SMOKE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func seed_party() -> void:
	GameState.start_new_game("warrior")
	GameState.set_flag("overworld_onboarding_seen")
	GameState.set_flag("battle_onboarding_seen")


func check_classes() -> void:
	var atlas_regions: Array[Rect2] = []
	for class_id in GameState.DEFAULT_CREST_BY_CLASS:
		GameState.start_new_game(class_id)
		var key := "aren/" + str(class_id)
		var record := CharacterPresentation.record_for(key)
		check(record.get("class_id", "") == class_id, "Class resolves to wrong outfit: " + key)
		var region := CharacterPresentation.rect(record.battle_rect)
		check(not atlas_regions.has(region), "Classes share an outfit crop: " + key)
		atlas_regions.append(region)
		check(CharacterPresentation.portrait(key) != null, "Class portrait missing: " + key)
		var parent := Node2D.new()
		add_child(parent)
		var walker := OverworldSprite.new()
		check(walker.attach(parent, key), "Class overworld missing: " + key)
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			walker.set_facing(direction)
			var bounds := Rect2(Vector2.ZERO, walker._sprite.texture.get_size())
			check(bounds.encloses(walker._sprite.region_rect), "Class direction out of atlas: " + key)
		for side in ["player", "enemy"]:
			var unit := BattleUnit.create(GameState.party[0], side, GameData)
			var stage := BattleStage.new()
			parent.add_child(stage)
			var sprite := stage.add_combatant(unit, 1)
			check(sprite._has_sheet and sprite._sprite.flip_h == (side == "enemy"), "Class facing failed: " + key)
		parent.queue_free()
		await get_tree().process_frame


func check_dialogue() -> void:
	var box := DialogueBox.new()
	add_child(box)
	await get_tree().process_frame
	var keys: Array[String] = ["aren/warrior", "elara", "mira"]
	for path in ["res://data/dialogue/greymere.json", "res://data/dialogue/hollow_court.json"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for entries in data.values():
			for entry in entries:
				var key: String = str(entry.get("portrait", ""))
				if not key.is_empty() and not keys.has(key): keys.append(key)
	for key in keys:
		box._apply_portrait(key, "determined")
		await get_tree().process_frame
		check(box._portrait.texture != null, "Missing portrait: " + key)
		check(box._portrait.size == PresentationLayout.PORTRAIT_RECT.size, "Portrait expanded: " + key)
		check(box._text_label.position.x >= box._portrait.position.x + box._portrait.size.x, "Portrait/text collision: " + key)
	var original := "A long sentence about the Hollow Court and its forgotten history. ".repeat(40)
	var font: Font = box._text_label.get_theme_font("font")
	var pages := DialogueBox.paginate(original, font, 8, 180, 28)
	check(pages.size() > 1, "Long dialogue not paginated")
	var reconstructed := " ".join(pages).replace("\n", " ").strip_edges()
	check(reconstructed == original.strip_edges(), "Pagination lost or reordered words")
	for page in pages:
		for line in page.split("\n"):
			check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x <= 180, "Text exceeds line width")
	box._dialogue_data = {"test": [{"speaker": "An exceptionally long speaker title", "portrait": "elara", "lines": [original, "Final line."]}]}
	box.play("test")
	var advances := 0
	while box.active and advances < 500:
		box._advance()
		advances += 1
	check(not box.active and advances > 2, "Dialogue did not finish after all pages")
	box.queue_free()
	await get_tree().process_frame


func press(event: InputEvent) -> void:
	## A real press and release through Input, as the player makes it.
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func pad_event(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func check_story_dialogue() -> void:
	## Staged story scenes: the reveal, Confirm completing it before advancing,
	## keyboard and controller parity, staging, missing art and long lines.
	seed_party()
	var box := DialogueBox.new()
	add_child(box)
	await get_tree().process_frame
	box.load_file("res://data/dialogue/greymere.json")
	box.play("court_entrance")
	await get_tree().process_frame
	check(box.staged and box._stage.visible, "Story key did not stage")
	check(box._stage.has_figure("elara") and box._stage.has_figure("mira"), "Story cast missing from stage")
	check(box._stage.has_figure(StoryStage.player_key()), "Kai missing from story stage")
	check(box._stage.figure_x(StoryStage.player_key()) < 160.0 and box._stage.figure_x("elara") > 160.0, "Story eyelines not opposed")
	check(box.revealing and box._text_label.visible_characters < box._text_label.get_total_character_count(), "Line did not reveal gradually")
	check(not box._advance_chevron.visible, "Continue cue shown before the line finished")
	# Confirm (Z) completes the reveal and stays on the line.
	var at := [box._entry_index, box._line_index, box._page_index]
	await press(key_event(KEY_Z))
	check(not box.revealing and box._text_label.visible_characters == -1, "Confirm did not complete the reveal")
	check([box._entry_index, box._line_index, box._page_index] == at, "First confirm skipped the line")
	check(box._advance_chevron.visible, "Continue cue missing after reveal")
	# The next press advances; a controller A press behaves the same.
	await press(pad_event(JOY_BUTTON_A))
	check([box._entry_index, box._line_index, box._page_index] != at and box.revealing, "Second confirm did not advance")
	await press(pad_event(JOY_BUTTON_A))
	check(not box.revealing, "Controller confirm did not complete the reveal")
	# The reveal finishes on its own too.
	await press(key_event(KEY_Z))
	for i in 400:
		if not box.revealing: break
		await get_tree().process_frame
	check(not box.revealing, "Reveal never finished on its own")
	# Walk to Almyra's line: she is lit and forward, the others sink.
	var guard := 0
	while box.active and str(box._entries[box._entry_index].get("portrait", "")) != "elara" and guard < 50:
		box.confirm()
		guard += 1
	await get_tree().create_timer(0.3).timeout
	var almyra: Node2D = box._stage._figures["almyra"]
	var liora: Node2D = box._stage._figures["liora"]
	check(almyra.modulate.r > 0.95 and liora.modulate.r < 0.7 and almyra.get_index() > liora.get_index(), "Active speaker not emphasised")
	check(box._tab.visible and box._tab_label.text == "WARDEN ALMYRA", "Nameplate missing for the speaker")
	check(box._tab.position.x > 160.0, "Nameplate not on the speaker's side")
	check(not box._portrait.visible, "Staged speaker also shown as a small portrait")
	check(box._stage.get_index() < box._panel.get_index() and box._stage.get_index() < box._tab.get_index(), "Story figures drawn over the panel")
	for holder in box._stage._figures.values():
		check((holder as Node2D).z_index == 0 and not (holder as Node2D).z_as_relative == false, "Story figure escapes the layer order")
	guard = 0
	while box.active and guard < 200:
		box.confirm()
		guard += 1
	check(not box.active and not box._stage.visible and not box._tab.visible, "Story scene did not close cleanly")
	# Incidental chat keeps the compact box.
	box.play("toby_flavor")
	await get_tree().process_frame
	check(not box.staged and not box._stage.visible and box._panel.size == PresentationLayout.DIALOGUE_RECT.size, "Incidental dialogue was staged")
	while box.active:
		box.confirm()
	# A staged scene with a speaker who has no large art, and a long line.
	var long_line := "The seal on the Hollow Court was laid by hands older than any banner in Greymere, and it has held. ".repeat(6)
	box._dialogue_data["staged_test"] = [{"staging": "scene", "speaker": "Joey", "portrait": "townsfolk/farmboy", "lines": [long_line]}]
	box.play("staged_test")
	await get_tree().process_frame
	check(box.staged and not box._stage.has_figure("townsfolk/farmboy"), "Speaker without art got a figure")
	check(box._portrait.visible, "Speaker without large art lost their portrait")
	check(box._pages.size() > 1, "Long staged line not paginated")
	var font: Font = box._text_label.get_theme_font("font")
	var rows := 0
	for page in box._pages:
		rows = maxi(rows, page.split("\n").size())
	var line_height := font.get_height(DialogueBox.STORY_FONT_SIZE) + PresentationLayout.DIALOGUE_LINE_GAP
	check(rows * line_height <= DialogueBox.STORY_TEXT_RECT.size.y + PresentationLayout.DIALOGUE_LINE_GAP, "Staged page overflows the panel")
	var reconstructed := " ".join(box._pages).replace("\n", " ").strip_edges()
	check(reconstructed == long_line.strip_edges(), "Staged pagination lost words")
	while box.active:
		box.confirm()
	box.queue_free()
	await get_tree().process_frame


func check_command_feedback() -> void:
	## Unavailable battle commands can be focused, say why, and refuse.
	seed_party()
	var unit := BattleUnit.create(GameState.party[0], "player", GameData)
	var resting: Dictionary = unit.moves[1]
	unit.cooldowns[unit.move_id_of(resting)] = 2
	var menu := ActionMenu.new()
	add_child(menu)
	menu.build_for(unit)
	check(menu.current_entry().enabled, "Command menu opened on an unavailable move")
	var guard := 0
	while menu.current_entry().move != resting and guard < 10:
		menu.move_cursor(1)
		guard += 1
	check(menu.current_entry().move == resting and not menu.current_entry().enabled, "Cursor cannot focus an unavailable move")
	check("ready in 2 rounds" in str(menu.current_entry().description), "Unavailable move gives no reason")
	var rest := menu.position.x
	menu.refuse()
	menu.refuse()
	await get_tree().create_timer(0.3).timeout
	check(is_equal_approx(menu.position.x, rest), "Refusal shake left the menu displaced")
	menu.queue_free()
	# Hint caps follow the device the player last used.
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_B
	await press(pad)
	check(InputDevice.cap("interact") == "A" and InputDevice.cap("cancel") == "B", "Hints did not switch to controller")
	await press(key_event(KEY_X))
	check(InputDevice.cap("interact") == "Z" and InputDevice.cap("cancel") == "X", "Hints did not switch back to keys")
	var bar := HintBar.create(self, Rect2(0, 0, 320, 12), [["move_v", "Choose"], ["interact", "Confirm"], ["cancel", "Back"]])
	check(bar.content_width() > 40.0 and bar.content_width() < 320.0, "Hint bar does not fit the canvas")
	bar.queue_free()
	await get_tree().process_frame


func check_formations() -> void:
	seed_party()
	for encounter_id in GameData.datasets.encounters:
		var runtime := EncounterRuntime.start(encounter_id, GameData, GameState)
		var stage := BattleStage.new()
		add_child(stage)
		for unit in runtime.all_units():
			if unit.sprite_key().is_empty():
				# Later data-only encounters lack art assignments. Report the coverage
				# gap explicitly; do not substitute an unrelated combatant or certify it.
				print("ART_COVERAGE_GAP: %s / %s" % [encounter_id, unit.display_name])
				continue
			var count := runtime.player_units.size() if unit.team == "player" else runtime.enemy_units.size()
			for row in ["front", "back"]:
				unit.position = row
				var sprite := stage.add_combatant(unit, count)
				check(sprite._has_sheet, "Missing sprite " + unit.sprite_key())
				if not sprite._has_sheet:
					continue
				check(sprite._sprite.flip_h == (unit.team == "enemy"), "Wrong facing " + unit.sprite_key())
				var anchor := PresentationLayout.mirrored_anchor(sprite._anchor, sprite._frame_w, sprite._sprite.flip_h)
				check((sprite._sprite.position + anchor * sprite._display_scale).length() < 0.01, "Foot anchor drift")
				check(sprite.position.y < PresentationLayout.BATTLE_HEIGHT - 8, "Combatant enters HUD")
				check(sprite.position.x < 160 if unit.team == "player" else sprite.position.x > 160, "Team crosses centre")
		stage.queue_free()
		await get_tree().process_frame


func check_enemy_hud() -> void:
	seed_party()
	var builds: Array = GameData.get_encounter("hollow_court_battle").enemy_party
	for sizes in [[1,1],[2,2],[3,1],[3,3]]:
		var hud := BattleHud.new()
		add_child(hud)
		await get_tree().process_frame
		var players: Array = []
		var enemies: Array = []
		for i in sizes[0]:
			var player := BattleUnit.create(GameState.party[i], "player", GameData)
			player.slot_index = i
			players.append(player)
		for i in sizes[1]:
			var enemy := BattleUnit.create(builds[i], "enemy", GameData)
			enemy.slot_index = i
			enemies.append(enemy)
		hud.build_rows(players)
		hud.build_turn_rail(players + enemies)
		check(hud._tokens.size() == players.size() + enemies.size(), "Turn rail count %s" % str(sizes))
		hud.highlight_unit(players[0])
		var placed: Array = hud._tokens.values()
		placed.sort_custom(func(a, b): return a.position.x < b.position.x)
		var prior_end := 0.0
		for token in placed:
			check(token.position.x >= prior_end and token.position.x + token.size.x <= 236, "Turn tokens overlap or reach the title box")
			prior_end = token.position.x + token.size.x
		check(hud._tokens[players[0]].lead, "Commanded Duelist leads the rail")
		for enemy in enemies:
			check(hud._tokens[enemy].unit == enemy, "Turn token must read authoritative unit")
		enemies[0].take_damage(5)
		hud.refresh_rows()
		hud.highlight_enemy(enemies[0])
		check(hud._tokens[enemies[0]].selected, "Selected enemy token")
		hud.queue_free()
		await get_tree().process_frame


func check_world_and_setup() -> void:
	seed_party()
	var world: Node = load("res://scenes/overworld/greymere.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	check(world._player._has_sheet, "Overworld hero missing")
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		world._player._sprite.set_facing(direction)
		check(world._player._sprite._sprite.region_rect.size == Vector2(world._player._sprite.frame_width, world._player._sprite.frame_height), "Overworld crop invalid")
	world._play_dialogue("kassian_flavor")
	check(world._camera.offset.y > 0, "Dialogue camera safe area not applied")
	while world._dialogue.active: world._dialogue._advance()
	check(world._camera.offset == Vector2.ZERO, "Dialogue camera not restored")
	world.queue_free()
	await get_tree().process_frame
	var setup: Node = load("res://scenes/ui/party_setup.tscn").instantiate()
	add_child(setup)
	await get_tree().process_frame
	for i in GameState.party.size():
		setup._cursor = i
		setup._refresh()
		await get_tree().process_frame
		check(setup._portrait.size == Vector2(34, 40), "Party portrait expanded")
	setup.queue_free()
	await get_tree().process_frame


func check_battle_flow(force_defeat: bool) -> void:
	seed_party()
	seed(41)
	var scene: Node = load("res://scenes/battle/party_battle.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	while scene.dialogue.active: scene.dialogue._advance()
	# Test-only health fixtures make both result screens deterministic while
	# attacks, targeting, AI and damage still run through the actual runtime.
	if force_defeat:
		for unit in scene.runtime.player_units: unit.hp = 1
	else:
		for unit in scene.runtime.enemy_units: unit.hp = 1
	Engine.time_scale = 50
	var steps := 0
	while scene.state != scene.State.RESULT and steps < 20000:
		if scene.state == scene.State.SELECT_MENU:
			if force_defeat: scene.hud.action_menu.cursor = scene.hud.action_menu.entries.size() - 1
		if scene.state in [scene.State.SELECT_MENU, scene.State.SELECT_TARGET, scene.State.PREVIEW]:
			var event := InputEventAction.new()
			event.action = "interact"
			event.pressed = true
			scene._unhandled_input(event)
		await get_tree().process_frame
		steps += 1
	check(scene.state == scene.State.RESULT, "Battle did not reach result")
	print("BATTLE_SMOKE_RESULT: force_defeat=%s victory=%s defeat=%s" % [force_defeat, scene.runtime.victory(), scene.runtime.defeat()])
	check(scene.runtime.defeat() if force_defeat else scene.runtime.victory(), "Unexpected battle result")
	check(scene.result_presentation != null, "Result presentation missing")
	Engine.time_scale = 1
	scene.queue_free()
	await get_tree().process_frame
