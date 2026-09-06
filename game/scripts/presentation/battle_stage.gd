class_name BattleStage
extends Node2D
## Scene staging owns backgrounds and combatant geometry, never battle resolution.

func build_background(location: String) -> void:
	var path := "res://assets/rework/hollow_court.png" if location == "hollow_court" else "res://assets/battle/backgrounds/%s.png" % location
	if not ResourceLoader.exists(path):
		push_error("BattleStage: required background missing: " + path)
		return
	var background := TextureRect.new()
	background.texture = load(path)
	PresentationLayout.texture_box(background, PresentationLayout.battlefield_rect())
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	PresentationLayout.use_source_art_filter(background)
	background.z_index = -20
	add_child(background)


func add_combatant(unit: BattleUnit, count: int) -> DuelistSprite:
	var sprite := DuelistSprite.new()
	add_child(sprite)
	var home := PresentationLayout.stage_position(unit.team, unit.slot_index, count, unit.position)
	sprite.configure(unit, home)
	sprite.z_index = int(home.y)
	return sprite
