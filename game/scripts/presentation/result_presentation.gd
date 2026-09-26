class_name ResultPresentation
extends CanvasLayer
## Dedicated result beat with optional authored ornament and geometric fallback.

signal acknowledged

const BANNER_SIZE := Vector2(168, 60)

var _active := false


func show_result(victory: bool) -> void:
	layer = 20
	_active = true
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.025, 0.06, 0.78)
	shade.size = Vector2(320, 180)
	add_child(shade)
	var key := "victory" if victory else "defeat"
	# One shared-style banner: gold (command) for victory, neutral slate for
	# defeat, so results read with the same panel grammar as the HUD.
	var banner := UiPanel.create(Vector2(76, 58), BANNER_SIZE, UiStyle.COMMAND if victory else UiStyle.NEUTRAL)
	add_child(banner)
	var path := "res://assets/ui/results/%s.png" % key
	if ResourceLoader.exists(path):
		var ornament := TextureRect.new()
		ornament.texture = load(path)
		PresentationLayout.texture_box(ornament, Rect2(80, 24, 160, 32))
		add_child(ornament)
	_line(banner, key.to_upper(), 8, 20, 14,
		PlaceholderPalette.CREST_GOLD_BRIGHT if victory else Color("b7aec8"))
	var divider := ColorRect.new()
	divider.color = (PlaceholderPalette.CREST_GOLD if victory else UiStyle.SURFACE_LINE)
	divider.position = Vector2(24, 31)
	divider.size = Vector2(120, 1)
	banner.add_child(divider)
	_line(banner, "ENCOUNTER WON" if victory else "THE PARTY HAS FALLEN", 34, 12, 8, PlaceholderPalette.TEXT_MAIN)
	var prompt := _line(banner, "Z  CONTINUE", 46, 12, 8, PlaceholderPalette.TEXT_DIM)
	# Subtle entrance: the shade and banner fade in, the banner settles into
	# place, and the prompt breathes so the screen never looks frozen.
	shade.modulate.a = 0.0
	banner.modulate.a = 0.0
	banner.position.y += 6
	var enter := create_tween().set_parallel(true)
	enter.tween_property(shade, "modulate:a", 1.0, 0.25)
	enter.tween_property(banner, "modulate:a", 1.0, 0.3).set_delay(0.1)
	enter.tween_property(banner, "position:y", 58.0, 0.3).set_delay(0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var pulse := create_tween().set_loops()
	pulse.tween_property(prompt, "modulate:a", 0.55, 0.8)
	pulse.tween_property(prompt, "modulate:a", 1.0, 0.8)
	AudioRouter.play_music(key)
	AudioRouter.play_sfx("battle", key)


func _line(parent: Control, text: String, y: float, height: float, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	# Geometry after the theme overrides, so the label keeps the full banner
	# width instead of the width of whichever line was measured first.
	label.position = Vector2(0, y)
	label.size = Vector2(BANNER_SIZE.x, height)
	return label


func _unhandled_input(event: InputEvent) -> void:
	if _active and event.is_action_pressed("interact"):
		_active = false
		get_viewport().set_input_as_handled()
		acknowledged.emit()
		queue_free()
