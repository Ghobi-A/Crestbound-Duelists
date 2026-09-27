extends CanvasLayer
class_name WorldHud
## Exploration HUD: a location plate top-left, a context prompt bottom-right
## and the pause menu. Both plates dissolve into the scene instead of
## boxing it in, so the authored town stays the focus.
var location_label: Label
var prompt: Label
var menu: UiPanel
var _scrim: ColorRect
var menu_status: Label
var _menu_rows: Array[Label] = []
var _menu_band: UiDecor
const MENU_SIZE := Vector2(150, 92)
const MENU_PADDING := 10.0
const HUD_HEIGHT := 12.0
const ROW_TOP := 22.0
const ROW_HEIGHT := 11.0
const CHOICES := ["Resume", "Save game", "Inventory", "Title screen"]

func _ready() -> void:
	layer = 5
	var canvas := PresentationLayout.CANVAS
	add_child(UiDecor.create("fade_left", Rect2(0, 0, 150, HUD_HEIGHT)))
	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var mark := UiDecor.create("rule", Rect2(3, HUD_HEIGHT / 2.0 - 2, 6, 4))
	plate.add_child(mark)
	location_label = UiStyle.make_label(plate, Rect2(12, 2.5, 130, 8), "", 6, UiStyle.GOLD_BRIGHT, UiStyle.MEDIUM, 1)
	add_child(UiDecor.create("fade_right", Rect2(canvas.x - 150, canvas.y - HUD_HEIGHT, 150, HUD_HEIGHT)))
	prompt = UiStyle.make_label(self, Rect2(canvas.x - 146, canvas.y - HUD_HEIGHT + 3, 140, 7), "", 5, UiStyle.TEXT_DIM, UiStyle.REGULAR, 1)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scrim = ColorRect.new()
	_scrim.color = Color(0.02, 0.03, 0.06, 0.62)
	_scrim.size = canvas
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.visible = false
	add_child(_scrim)
	menu = UiPanel.create(((canvas - MENU_SIZE) / 2).round(), MENU_SIZE, UiStyle.COMMAND).with_divider(15)
	add_child(menu)
	var title := UiStyle.make_label(menu, Rect2(0, 4, MENU_SIZE.x, 9), "PAUSED", 6, UiStyle.GOLD_BRIGHT, UiStyle.MEDIUM, 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_band = UiDecor.create("selection", Rect2(MENU_PADDING + 6, ROW_TOP, MENU_SIZE.x - 2 * MENU_PADDING - 8, ROW_HEIGHT - 2))
	menu.add_child(_menu_band)
	for i in CHOICES.size():
		var row := UiStyle.make_label(menu, Rect2(MENU_PADDING + 11, ROW_TOP + i * ROW_HEIGHT, 110, ROW_HEIGHT - 2), CHOICES[i], 6, UiStyle.TEXT, UiStyle.MEDIUM)
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_menu_rows.append(row)
	menu_status = UiStyle.make_label(menu, Rect2(MENU_PADDING, 60, MENU_SIZE.x - 2 * MENU_PADDING, 8), "", 5, UiStyle.TEXT_DIM)
	menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hints := UiStyle.make_label(menu, Rect2(MENU_PADDING, 77, MENU_SIZE.x - 2 * MENU_PADDING, 8), "Z SELECT   ·   ESC RETURN", 5, UiStyle.TEXT_FAINT, UiStyle.REGULAR, 1)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.visible = false

func show_context(verb: String) -> void:
	prompt.text = ("Z " + verb + "   ·   ESC MENU" if verb != "" else "ESC MENU").to_upper()

func show_menu(cursor: int, status: String) -> void:
	_scrim.visible = true
	menu.visible = true
	var selected := clampi(cursor, 0, CHOICES.size() - 1)
	_menu_band.position.y = ROW_TOP + selected * ROW_HEIGHT
	for i in _menu_rows.size():
		_menu_rows[i].add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT if i == selected else UiStyle.TEXT_DIM)
	menu_status.text = status


func hide_menu() -> void:
	menu.visible = false
	_scrim.visible = false
