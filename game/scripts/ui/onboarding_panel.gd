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

	# The panel is sized to what it holds. 832x416 was the 320x180 box
	# multiplied up, and it stood roughly twice as tall as its six lines.
	var inner := 36.0
	var rows := _Rows.new()
	rows.rows = _parse(body)
	# Wrapping is resolved against the real measure before the panel is
	# sized, so the height always matches what will actually be drawn.
	# Clipping instead of wrapping cost the objective line its last two
	# words — "investigate the Hollow Co".
	var content_height := rows.prepare(760.0 - inner * 2)
	var title_height := Typography.line_height(Typography.Role.TITLE) * 1.3
	var hint_height := Typography.line_height(Typography.Role.SECONDARY) * 1.4
	var panel_size := Vector2(760.0,
		inner + title_height + UiStyle.SPACE_M + content_height + UiStyle.SPACE_L + hint_height + inner)
	var origin := (PresentationLayout.CANVAS - panel_size) * 0.5

	var panel := UiPanel.create(origin, panel_size, UiStyle.COMMAND)
	add_child(panel)

	var title_label := Label.new()
	title_label.text = title
	title_label.position = Vector2(inner, inner * 0.7)
	title_label.size = Vector2(panel_size.x - inner * 2, title_height)
	Typography.apply(title_label, Typography.Role.TITLE, PlaceholderPalette.CREST_GOLD_BRIGHT)
	panel.add_child(title_label)

	rows.position = Vector2(inner, inner * 0.7 + title_height + UiStyle.SPACE_M)
	rows.size = Vector2(panel_size.x - inner * 2, content_height)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rows)

	var hint_label := Label.new()
	hint_label.text = "Z / Enter / Space: dismiss"
	hint_label.position = Vector2(inner, panel_size.y - inner * 0.7 - hint_height)
	hint_label.size = Vector2(panel_size.x - inner * 2, hint_height)
	Typography.apply(hint_label, Typography.Role.SECONDARY, PlaceholderPalette.TEXT_DIM)
	panel.add_child(hint_label)


static func _parse(body: String) -> Array[Dictionary]:
	## Callers still pass one string with control names and their keys
	## separated by runs of spaces. That only ever lined up because the
	## bitmap face was fixed width; under a proportional serif the columns
	## drifted. The run of spaces is now read as a column break and laid
	## out properly, so the callers did not have to change.
	var rows: Array[Dictionary] = []
	for line in body.split("\n"):
		if line.strip_edges().is_empty():
			rows.append({"kind": "gap"})
			continue
		var split := line.split("  ", false)
		if split.size() >= 2:
			rows.append({"kind": "pair", "label": split[0].strip_edges(),
				"value": " ".join(split.slice(1)).strip_edges()})
		else:
			rows.append({"kind": "text", "text": line.strip_edges()})
	return rows


class _Rows:
	extends Control
	## Two-column control list plus free paragraphs.
	var rows: Array[Dictionary] = []

	static func line() -> float:
		return Typography.line_height(Typography.Role.BODY) * 1.25

	func prepare(width: float) -> float:
		## Resolves paragraph wrapping and returns the height needed.
		var total := 0.0
		for row in rows:
			var kind := str(row.get("kind", ""))
			if kind == "gap":
				total += line() * 0.5
				continue
			if kind == "text":
				var wrapped := _wrap(str(row.get("text", "")), width)
				row["lines"] = wrapped
				total += line() * float(wrapped.size())
				continue
			total += line()
		return total

	static func _wrap(text: String, width: float) -> PackedStringArray:
		var lines := PackedStringArray()
		var current := ""
		for word in text.split(" ", false):
			var candidate := word if current.is_empty() else current + " " + word
			if Typography.measure(Typography.Role.BODY, candidate).x <= width or current.is_empty():
				current = candidate
			else:
				lines.append(current)
				current = word
		if not current.is_empty():
			lines.append(current)
		return lines

	func _draw() -> void:
		var y := 0.0
		# The key column starts at a fixed measure so every row's keys
		# align, which is what the runs of spaces were reaching for.
		var value_x := size.x * 0.34
		for row in rows:
			var kind := str(row.get("kind", ""))
			if kind == "gap":
				y += line() * 0.5
				continue
			var baseline := y + Typography.size(Typography.Role.BODY)
			if kind == "pair":
				Typography.draw(self, Typography.Role.BODY, Vector2(0, baseline),
					str(row.get("label", "")), PlaceholderPalette.TEXT_DIM, value_x)
				Typography.draw(self, Typography.Role.BODY, Vector2(value_x, baseline),
					str(row.get("value", "")), PlaceholderPalette.TEXT_MAIN, size.x - value_x)
			else:
				var wrapped: PackedStringArray = row.get("lines", PackedStringArray())
				for i in wrapped.size():
					Typography.draw(self, Typography.Role.BODY,
						Vector2(0, baseline + line() * float(i)), wrapped[i],
						PlaceholderPalette.TEXT_MAIN, size.x)
				y += line() * float(maxi(1, wrapped.size() - 1))
			y += line()


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
