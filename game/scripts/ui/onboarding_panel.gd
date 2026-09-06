extends CanvasLayer
class_name OnboardingPanel
## Small dismissible onboarding overlay shown on first entry to the
## overworld and to battle, so a recruiter understands controls and
## the immediate objective without reading the README.

signal dismissed

var active := false


func _ready() -> void:
	layer = 20
	visible = false


func show_panel(title: String, body: String) -> void:
	active = true
	visible = true
	_build(title, body)


func _build(title: String, body: String) -> void:
	for child in get_children():
		child.queue_free()

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var panel := UiPanel.create(Vector2(224, 152), Vector2(832, 416), UiStyle.COMMAND).with_divider(72)
	add_child(panel)

	var title_label := Label.new()
	title_label.text = title
	title_label.position = Vector2(32, 28)
	title_label.size = Vector2(768, Typography.HEADING + 8)
	title_label.add_theme_font_size_override("font_size", Typography.HEADING)
	title_label.add_theme_color_override("font_color", PlaceholderPalette.TEXT_WARN)
	panel.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body
	body_label.position = Vector2(32, 96)
	body_label.size = Vector2(768, 248)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", Typography.BODY)
	body_label.add_theme_color_override("font_color", PlaceholderPalette.TEXT_MAIN)
	panel.add_child(body_label)

	var hint_label := Label.new()
	hint_label.text = "Z / Enter / Space: dismiss"
	hint_label.position = Vector2(32, 360)
	hint_label.size = Vector2(768, Typography.BODY + 8)
	hint_label.add_theme_font_size_override("font_size", Typography.BODY)
	hint_label.add_theme_color_override("font_color", PlaceholderPalette.TEXT_DIM)
	panel.add_child(hint_label)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_pressed() and not event.is_echo() and (event.is_action_pressed("interact") or event.is_action_pressed("cancel")):
		get_viewport().set_input_as_handled()
		_dismiss()


func _dismiss() -> void:
	active = false
	visible = false
	dismissed.emit()
