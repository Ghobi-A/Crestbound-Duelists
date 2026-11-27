extends CanvasLayer
class_name WorldHud
## Exploration HUD: a location plate top-left, a context prompt bottom-right
## and the pause menu. Both plates dissolve into the scene instead of
## boxing it in, so the authored town stays the focus. Quest updates
## (GameState.quest_updated) show briefly under the location plate.
var location_label: Label
var prompt: HintBar
var menu: UiPanel
var _scrim: ColorRect
var menu_status: Label
var _menu_rows: Array[Label] = []
var _menu_band: UiDecor
var _notice: Control
var _notice_label: Label
var _notice_tween: Tween
var _pending_notices: Array[String] = []
var _notice_showing := false
const NOTICE_SECONDS := 2.6
const MENU_SIZE := Vector2(150, 110)
const MENU_PADDING := 10.0
const HUD_HEIGHT := 12.0
const ROW_TOP := 22.0
const ROW_HEIGHT := 11.0
const CHOICES := ["Resume", "Save game", "Inventory", "Graphics", "Title screen"]
const GRAPHICS_ROW := 3

func _ready() -> void:
	layer = 5
	# After WorldLocation (priority 10) has shown or hidden the HUD this frame.
	process_priority = 20
	var canvas := PresentationLayout.CANVAS
	add_child(UiDecor.create("fade_left", Rect2(0, 0, 150, HUD_HEIGHT)))
	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var mark := UiDecor.create("rule", Rect2(3, HUD_HEIGHT / 2.0 - 2, 6, 4))
	plate.add_child(mark)
	location_label = UiStyle.make_label(plate, Rect2(12, 1.8, 136, 9), "", 6, UiStyle.GOLD_BRIGHT, UiStyle.DISPLAY, 1)
	_notice = Control.new()
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.modulate.a = 0.0
	add_child(_notice)
	_notice.add_child(UiDecor.create("fade_left", Rect2(0, HUD_HEIGHT + 1, 190, 10)))
	_notice_label = UiStyle.make_label(_notice, Rect2(12, HUD_HEIGHT + 2.2, 176, 8), "", 5, UiStyle.TEXT, UiStyle.MEDIUM)
	GameState.quest_updated.connect(_on_quest_updated)
	add_child(UiDecor.create("fade_right", Rect2(canvas.x - 150, canvas.y - HUD_HEIGHT, 150, HUD_HEIGHT)))
	prompt = HintBar.create(self, Rect2(canvas.x - 150, canvas.y - HUD_HEIGHT, 144, HUD_HEIGHT), [["cancel", "Menu"]], HORIZONTAL_ALIGNMENT_RIGHT)
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
	menu_status = UiStyle.make_label(menu, Rect2(MENU_PADDING, 80, MENU_SIZE.x - 2 * MENU_PADDING, 8), "", 5, UiStyle.TEXT_DIM)
	menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HintBar.create(menu, Rect2(MENU_PADDING, 95, MENU_SIZE.x - 2 * MENU_PADDING, 10), [["interact", "Select"], ["cancel", "Return"]])
	menu.visible = false

func show_context(verb: String) -> void:
	# The action you can take right now leads, lit; the menu stays behind it.
	prompt.colour = UiStyle.TEXT if verb != "" else UiStyle.TEXT_DIM
	prompt.set_items([["interact", verb], ["cancel", "Menu"]] if verb != "" else [["cancel", "Menu"]])
	prompt.queue_redraw()

func show_menu(cursor: int, status: String) -> void:
	_scrim.visible = true
	menu.visible = true
	var selected := clampi(cursor, 0, CHOICES.size() - 1)
	_menu_band.position.y = ROW_TOP + selected * ROW_HEIGHT
	for i in _menu_rows.size():
		_menu_rows[i].add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT if i == selected else UiStyle.TEXT_DIM)
	_menu_rows[GRAPHICS_ROW].text = "Graphics: " + GraphicsSettings.preset().capitalize()
	menu_status.text = status


func hide_menu() -> void:
	menu.visible = false
	_scrim.visible = false


func _on_quest_updated(_quest_id: String, text: String) -> void:
	# Most quest flags are set mid-conversation, while the HUD is hidden:
	# hold each line until the HUD is back, so it is seen and heard.
	_pending_notices.append(text)


func _process(_delta: float) -> void:
	if _notice_showing or _pending_notices.is_empty() or not visible:
		return
	_show_notice(_pending_notices.pop_front())


func _show_notice(text: String) -> void:
	## A journal entry changed: a line under the location plate, then gone.
	_notice_showing = true
	_notice_label.text = text
	_notice.modulate.a = 1.0
	AudioRouter.play_sfx("ui", "quest")
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_SECONDS)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.5)
	_notice_tween.tween_callback(func() -> void: _notice_showing = false)
