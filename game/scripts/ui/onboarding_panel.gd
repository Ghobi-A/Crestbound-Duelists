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
	scrim.color = Color(0.02, 0.03, 0.06, 0.62)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var panel := UiPanel.create(Vector2(40, 34), Vector2(240, 108), UiStyle.COMMAND).with_divider(16)
	add_child(panel)

	var title_label := UiStyle.make_label(panel, Rect2(0, 5, 240, 9), title.to_upper(), 6, UiStyle.GOLD_BRIGHT, UiStyle.MEDIUM, 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var body_label := UiStyle.make_label(panel, Rect2(12, 22, 216, 70), body, 6, UiStyle.TEXT)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_constant_override("line_spacing", 2)

	var hint_label := UiStyle.make_label(panel, Rect2(0, 96, 240, 7), "Z / ENTER / SPACE   ·   DISMISS", 5, UiStyle.TEXT_FAINT, UiStyle.REGULAR, 1)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


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
