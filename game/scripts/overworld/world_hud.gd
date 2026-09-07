extends CanvasLayer
class_name WorldHud
var location_label: Label
var prompt: Label
var menu: UiPanel
var menu_label: Label

func _ready() -> void:
	layer = 5
	var bar := UiPanel.create(Vector2(0,164),Vector2(320,16),UiStyle.NEUTRAL,false)
	add_child(bar)
	location_label = make_label(Vector2(7,3),Vector2(175,11),bar)
	location_label.add_theme_color_override("font_color",PlaceholderPalette.TEXT_WARN)
	prompt = make_label(Vector2(181,3),Vector2(132,11),bar)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu = UiPanel.create(Vector2(76,48),Vector2(168,88),UiStyle.COMMAND)
	add_child(menu)
	menu_label = make_label(Vector2(12,8),Vector2(144,74),menu)
	menu.visible = false

func make_label(at: Vector2, bounds: Vector2, parent: Node) -> Label:
	var label := Label.new()
	label.position = at
	label.size = bounds
	label.clip_text = true
	label.add_theme_font_size_override("font_size",8)
	parent.add_child(label)
	return label

func show_context(verb: String) -> void:
	prompt.text = "Z " + verb + "   ESC Menu" if verb != "" else "ESC Menu"

func show_menu(cursor: int, status: String) -> void:
	menu.visible = true
	var lines: Array[String] = ["GREYMERE", ""]
	var choices := ["Resume", "Save game", "Title screen"]
	for i in choices.size(): lines.append(("> " if i == cursor else "  ") + choices[i])
	lines.append(status)
	menu_label.text = "\n".join(lines)
