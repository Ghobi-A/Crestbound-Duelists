class_name ResultPresentation
extends CanvasLayer
## Dedicated result beat with optional authored ornament and geometric fallback.

signal acknowledged
## "continue", "retry" or "give_up" (retry choices only after a defeat
## in a battle that allows it).
signal chose(choice: String)

const BANNER_SIZE := Vector2(168, 60)

var _active := false
var _choices: Array = []
var _cursor := 0
var _choice_labels: Array = []


func show_result(victory: bool, rewards: Array = [], can_retry := false) -> void:
	layer = 20
	_active = true
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.025, 0.06, 0.78)
	shade.size = Vector2(320, 180)
	add_child(shade)
	var key := "victory" if victory else "defeat"
	# One shared-style banner: gold (command) for victory, neutral slate for
	# defeat, so results read with the same panel grammar as the HUD.
	var banner := UiPanel.create(Vector2(76, 50), BANNER_SIZE, UiStyle.COMMAND if victory else UiStyle.NEUTRAL)
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
	# Rewards sit under the banner, one per line.
	if victory and not rewards.is_empty():
		banner.size.y = BANNER_SIZE.y + 10 + rewards.size() * 9
		_line(banner, "REWARDS", 46, 8, 5, UiStyle.GOLD, UiStyle.MEDIUM, 1)
		for i in rewards.size():
			_line(banner, str(rewards[i]), 55 + i * 9, 9, 6, UiStyle.TEXT, UiStyle.SERIF, 0)
	_choices = ["retry", "give_up"] if (not victory and can_retry) else ["continue"]
	var hints: Control
	if _choices.size() == 1:
		hints = HintBar.create(banner, Rect2(0, banner.size.y - 13, BANNER_SIZE.x, 10), [["interact", "Continue"]])
	else:
		banner.size.y += 18
		for i in _choices.size():
			var label := _line(banner, ["Retry the battle", "Give up"][i], banner.size.y - 30 + i * 9, 9, 6, UiStyle.TEXT_DIM, UiStyle.SERIF, 0)
			_choice_labels.append(label)
		_refresh_choices()
		hints = HintBar.create(banner, Rect2(0, banner.size.y - 11, BANNER_SIZE.x, 10), [["move_v", "Choose"], ["interact", "Confirm"]])
	# Subtle entrance: the shade and banner fade in, the banner settles into
	# place, and the prompt breathes so the screen never looks frozen.
	shade.modulate.a = 0.0
	banner.modulate.a = 0.0
	banner.position.y += 6
	var enter := create_tween().set_parallel(true)
	enter.tween_property(shade, "modulate:a", 1.0, 0.25)
	enter.tween_property(banner, "modulate:a", 1.0, 0.3).set_delay(0.1)
	enter.tween_property(banner, "position:y", (180.0 - banner.size.y) / 2.0, 0.3).set_delay(0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The prompt breathes so the screen never looks frozen.
	var pulse := create_tween().set_loops()
	pulse.tween_property(hints, "modulate:a", 0.55, 0.8)
	pulse.tween_property(hints, "modulate:a", 1.0, 0.8)
	AudioRouter.play_music(key)
	AudioRouter.play_sfx("battle", key)


func _line(parent: Control, text: String, y: float, height: float, size: int, colour: Color, weight: String, spacing: int) -> Label:
	var label := UiStyle.make_label(parent, Rect2(0, y, BANNER_SIZE.x, height), text, size, colour, weight, spacing)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _refresh_choices() -> void:
	for i in _choice_labels.size():
		var label: Label = _choice_labels[i]
		label.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT if i == _cursor else UiStyle.TEXT_DIM)
		label.text = ("▸ " if i == _cursor else "") + ["Retry the battle", "Give up"][i]


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if _choices.size() > 1 and (event.is_action_pressed("move_up") or event.is_action_pressed("move_down")):
		_cursor = wrapi(_cursor + 1, 0, _choices.size())
		_refresh_choices()
		AudioRouter.play_sfx("ui", "move")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_active = false
		get_viewport().set_input_as_handled()
		AudioRouter.play_sfx("ui", "confirm")
		chose.emit(str(_choices[_cursor]))
		acknowledged.emit()
		queue_free()
