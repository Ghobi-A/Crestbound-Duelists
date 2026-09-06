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
	await check_formations()
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
				check(sprite.position.y < 110, "Combatant enters HUD")
				check(sprite.position.x < 160 if unit.team == "player" else sprite.position.x > 160, "Team crosses centre")
		stage.queue_free()
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
	# Test-only health fixture accelerates defeat; the normal victory run uses
	# unmodified combat data, targeting, AI and damage calculations.
	if force_defeat:
		for unit in scene.runtime.player_units: unit.hp = 1
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
	check(scene.runtime.defeat() if force_defeat else scene.runtime.victory(), "Unexpected battle result")
	check(scene.result_presentation != null, "Result presentation missing")
	Engine.time_scale = 1
	scene.queue_free()
	await get_tree().process_frame
