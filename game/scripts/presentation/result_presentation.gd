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
		# Centred above the word, at a size the canvas can carry. The old
		# 160x32 box at (80, 24) was a 320x180 coordinate that survived the
		# resolution migration and pinned the ornament to the top-left.
		PresentationLayout.texture_box(ornament, Rect2(
			PresentationLayout.CANVAS.x * 0.5 - 180.0, PresentationLayout.CANVAS.y * 0.30,
			360.0, 72.0))
		add_child(ornament)
	var title := Label.new()
	title.text = key.to_upper()
	# The result is the whole screen's subject, so it sits on the optical
	# centre rather than near the top edge.
	title.position = Vector2(0, PresentationLayout.CANVAS.y * 0.44)
	title.size = Vector2(PresentationLayout.CANVAS.x, Typography.line_height(Typography.Role.DISPLAY) * 1.4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Typography.apply(title, Typography.Role.DISPLAY,
		PlaceholderPalette.CREST_GOLD_BRIGHT if victory else Color("b7aec8"))

	add_child(title)
	var prompt := Label.new()
	prompt.text = "Z  CONTINUE"
	prompt.position = Vector2(0, PresentationLayout.CANVAS.y * 0.44 + Typography.line_height(Typography.Role.DISPLAY) * 1.8)
	prompt.size = Vector2(PresentationLayout.CANVAS.x, Typography.line_height(Typography.Role.BODY) * 1.4)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Typography.apply(prompt, Typography.Role.SECONDARY, PlaceholderPalette.TEXT_DIM)

	add_child(prompt)
	# The same Crest rule the party-setup title uses, so the result beat
	# belongs to the same interface as everything before it.
	var rule := _ResultRule.new()
	rule.position = Vector2(PresentationLayout.CANVAS.x * 0.5 - 140.0,
		PresentationLayout.CANVAS.y * 0.44 + Typography.line_height(Typography.Role.DISPLAY) * 1.25)
	rule.size = Vector2(280.0, 16.0)
	rule.accent = PlaceholderPalette.CREST_GOLD if victory else Color("6a6478")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	AudioRouter.play_music(key)
	AudioRouter.play_sfx("battle", key)


class _ResultRule:
	extends Control
	var accent := Color.WHITE

	func _draw() -> void:
		var faded := accent
		faded.a = 0.0
		var mid := size.x * 0.5
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(mid, 0),
				Vector2(mid, UiStyle.LINE), Vector2(0, UiStyle.LINE)]),
			PackedColorArray([faded, accent, accent, faded]))
		draw_polygon(
			PackedVector2Array([Vector2(mid, 0), Vector2(size.x, 0),
				Vector2(size.x, UiStyle.LINE), Vector2(mid, UiStyle.LINE)]),
			PackedColorArray([accent, faded, faded, accent]))
		UiStyle.draw_crest_mark(self, Vector2(mid, UiStyle.LINE * 0.5), UiStyle.SPACE_S, accent)


func _unhandled_input(event: InputEvent) -> void:
	if _active and event.is_action_pressed("interact"):
		_active = false
		get_viewport().set_input_as_handled()
		acknowledged.emit()
		queue_free()
