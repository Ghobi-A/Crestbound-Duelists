extends CanvasLayer
class_name WorldHud
var location_label: Label
var prompt: Label
var menu: UiPanel
var menu_label: Label
var menu_status: Label
const MENU_SIZE := Vector2(184, 118)
const MENU_PADDING := 10.0
const HUD_HEIGHT := 16.0

func _ready() -> void:
	layer = 5
	var canvas := PresentationLayout.CANVAS
	var bar := UiPanel.create(Vector2(0, canvas.y - HUD_HEIGHT),Vector2(canvas.x, HUD_HEIGHT),UiStyle.NEUTRAL,false)
	add_child(bar)
	location_label = make_label(Vector2(7,3),Vector2(175,11),bar)
	location_label.add_theme_color_override("font_color",PlaceholderPalette.TEXT_WARN)
	prompt = make_label(Vector2(181,3),Vector2(132,11),bar)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu = UiPanel.create(((canvas - MENU_SIZE) / 2).round(), MENU_SIZE, UiStyle.COMMAND).with_divider(23)
	add_child(menu)
	var title := make_label(Vector2(MENU_PADDING, 8), Vector2(164, 12), menu)
	title.text = "PAUSED"
	title.add_theme_color_override("font_color", UiStyle.accent_color(UiStyle.COMMAND))
	menu_label = make_label(Vector2(MENU_PADDING, 30),Vector2(164, 49),menu)
	menu_label.add_theme_constant_override("line_spacing", 6)
	menu_status = make_label(Vector2(MENU_PADDING, 83), Vector2(164, 12), menu)
	var hints := make_label(Vector2(MENU_PADDING, 101), Vector2(164, 12), menu)
	hints.text = "Z Select   ESC Return"
	menu.visible = false

func make_label(at: Vector2, bounds: Vector2, parent: Node) -> Label:
	var label := Label.new()
	label.position = at
	label.size = bounds
	label.clip_text = true
	label.add_theme_font_size_override("font_size",UiStyle.FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func show_context(verb: String) -> void:
	prompt.text = "Z " + verb + "   ESC Menu" if verb != "" else "ESC Menu"

func show_menu(cursor: int, status: String) -> void:
	menu.visible = true
	var lines: Array[String] = []
	var choices := ["Resume", "Save game", "Title screen"]
	for i in choices.size(): lines.append(("> " if i == cursor else "  ") + choices[i])
	menu_label.text = "\n".join(lines)
	menu_status.text = status
