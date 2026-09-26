extends CanvasLayer
class_name WorldHud
var location_label: Label
var prompt: Label
var menu: UiPanel
var _scrim: ColorRect
var menu_status: Label
var _menu_rows: Array[Label] = []
var _menu_band: ColorRect
const MENU_SIZE := Vector2(184, 112)
const MENU_PADDING := 10.0
const HUD_HEIGHT := 16.0
const ROW_TOP := 30.0
const ROW_HEIGHT := 16.0
const CHOICES := ["Resume", "Save game", "Title screen"]

func _ready() -> void:
	layer = 5
	var canvas := PresentationLayout.CANVAS
	var bar := UiPanel.create(Vector2(0, canvas.y - HUD_HEIGHT),Vector2(canvas.x, HUD_HEIGHT),UiStyle.NEUTRAL,false)
	add_child(bar)
	location_label = make_label(Vector2(7,3),Vector2(175,11),bar)
	location_label.add_theme_color_override("font_color",PlaceholderPalette.TEXT_WARN)
	prompt = make_label(Vector2(181,3),Vector2(132,11),bar)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scrim = ColorRect.new()
	_scrim.color = Color(0.025, 0.04, 0.075, 0.56)
	_scrim.size = canvas
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.visible = false
	add_child(_scrim)
	menu = UiPanel.create(((canvas - MENU_SIZE) / 2).round(), MENU_SIZE, UiStyle.COMMAND).with_divider(23)
	add_child(menu)
	var title := make_label(Vector2(MENU_PADDING, 8), Vector2(164, 12), menu)
	title.text = "PAUSED"
	title.add_theme_color_override("font_color", UiStyle.accent_color(UiStyle.COMMAND))
	_menu_band = ColorRect.new()
	_menu_band.color = UiStyle.SURFACE_RAISED
	_menu_band.position = Vector2(6, ROW_TOP)
	_menu_band.size = Vector2(MENU_SIZE.x - 12, ROW_HEIGHT)
	_menu_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(_menu_band)
	var band_tick := ColorRect.new()
	band_tick.color = UiStyle.accent_color(UiStyle.COMMAND)
	band_tick.size = Vector2(1, ROW_HEIGHT)
	band_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_band.add_child(band_tick)
	for i in CHOICES.size():
		var row := make_label(Vector2(MENU_PADDING + 5, ROW_TOP + i * ROW_HEIGHT + 2), Vector2(154, 12), menu)
		row.text = CHOICES[i]
		_menu_rows.append(row)
	menu_status = make_label(Vector2(MENU_PADDING, 80), Vector2(164, 12), menu)
	var hints := make_label(Vector2(MENU_PADDING, 96), Vector2(164, 12), menu)
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
	_scrim.visible = true
	menu.visible = true
	var selected := clampi(cursor, 0, CHOICES.size() - 1)
	_menu_band.position.y = ROW_TOP + selected * ROW_HEIGHT
	for i in _menu_rows.size():
		_menu_rows[i].add_theme_color_override("font_color", UiStyle.accent_color(UiStyle.COMMAND) if i == selected else PlaceholderPalette.TEXT_MAIN)
	menu_status.text = status


func hide_menu() -> void:
	menu.visible = false
	_scrim.visible = false
