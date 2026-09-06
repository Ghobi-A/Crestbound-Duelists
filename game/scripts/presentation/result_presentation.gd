class_name ResultPresentation
extends CanvasLayer
## Dedicated result beat with optional authored ornament and geometric fallback.

signal acknowledged

var _active := false


func show_result(victory: bool) -> void:
	layer = 20
	_active = true
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.025, 0.06, 0.78)
	shade.size = PresentationLayout.CANVAS
	add_child(shade)
	var key := "victory" if victory else "defeat"
	var path := "res://assets/ui/results/%s.png" % key
	if ResourceLoader.exists(path):
		var ornament := TextureRect.new()
		ornament.texture = load(path)
		PresentationLayout.texture_box(ornament, Rect2(80, 24, 160, 32))
		add_child(ornament)
	var title := Label.new()
	title.text = key.to_upper()
	title.position = Vector2(0, 62)
	title.size = Vector2(PresentationLayout.CANVAS.x, Typography.line_height(Typography.Role.DISPLAY) * 1.4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Typography.apply(title, Typography.Role.DISPLAY,
		PlaceholderPalette.CREST_GOLD_BRIGHT if victory else Color("b7aec8"))

	add_child(title)
	var prompt := Label.new()
	prompt.text = "Z  CONTINUE"
	prompt.position = Vector2(0, 108)
	prompt.size = Vector2(PresentationLayout.CANVAS.x, Typography.line_height(Typography.Role.BODY) * 1.4)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Typography.apply(prompt, Typography.Role.SECONDARY, PlaceholderPalette.TEXT_DIM)

	add_child(prompt)
	AudioRouter.play_music(key)
	AudioRouter.play_sfx("battle", key)


func _unhandled_input(event: InputEvent) -> void:
	if _active and event.is_action_pressed("interact"):
		_active = false
		get_viewport().set_input_as_handled()
		acknowledged.emit()
		queue_free()
