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
	_line(banner, key.to_upper(), 9, 18, 14,
		UiStyle.GOLD_BRIGHT if victory else Color("b7aec8"), UiStyle.SEMIBOLD, 2)
	banner.with_divider(30)
	_line(banner, "ENCOUNTER WON" if victory else "THE PARTY HAS FALLEN", 34, 10, 6, UiStyle.TEXT, UiStyle.MEDIUM, 0)
	var prompt := _line(banner, "Z  CONTINUE", 46, 8, 5, UiStyle.TEXT_DIM, UiStyle.REGULAR, 0)
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


func _line(parent: Control, text: String, y: float, height: float, size: int, colour: Color, weight: String, spacing: int) -> Label:
	var label := UiStyle.make_label(parent, Rect2(0, y, BANNER_SIZE.x, height), text, size, colour, weight, spacing)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _unhandled_input(event: InputEvent) -> void:
	if _active and event.is_action_pressed("interact"):
		_active = false
		get_viewport().set_input_as_handled()
		acknowledged.emit()
		queue_free()
