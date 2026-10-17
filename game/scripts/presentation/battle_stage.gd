class_name BattleStage
extends Node2D
## Scene staging owns backgrounds and combatant geometry, never battle resolution.

func build_background(location: String) -> void:
	var outdoor: Dictionary = WorldCatalog.location(location).get("battle_background", {})
	if not outdoor.is_empty():
		var terrain := WorldTerrain.new()
		terrain.rows = outdoor.rows
		terrain.z_index = -20
		add_child(terrain)
		for item in outdoor.get("props", []):
			var prop := WorldProp.create(item)
			prop.z_index = -19
			add_child(prop)
		return
	var path := "res://assets/rework/hollow_court.png" if location == "hollow_court" else "res://assets/battle/backgrounds/%s.png" % location
	if not ResourceLoader.exists(path):
		push_error("BattleStage: required background missing: " + path)
		return
	var background := TextureRect.new()
	background.texture = load(path)
	PresentationLayout.texture_box(background, Rect2(0, 0, 320, PresentationLayout.BATTLE_HEIGHT))
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.z_index = -20
	add_child(background)


func add_combatant(unit: BattleUnit, count: int, opponent_count: int = 3) -> DuelistSprite:
	var sprite := DuelistSprite.new()
	add_child(sprite)
	var home := PresentationLayout.stage_position(unit.team, unit.slot_index, count, unit.position, opponent_count)
	sprite.configure(unit, home)
	sprite.z_index = int(home.y)
	return sprite
