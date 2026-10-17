extends CanvasLayer
class_name TradePanel
## Gell's counter and the field bag share one catalogue and one save state.

signal closed

const PANEL_RECT := Rect2(49, 25, 222, 129)
const LIST_TOP := 60.0
const ROW_HEIGHT := 13.0

var active := false
var shopping := false
var cursor := 0
var target := 0
var _panel: UiPanel
var _scrim: ColorRect
var _heading: Label
var _funds: Label
var _rows: Array[Label] = []
var _band: UiDecor
var _description: Label
var _party: Label
var _message: Label
var _items: Array = []

func _ready() -> void:
	layer = 9
	_scrim = ColorRect.new()
	_scrim.color = Color(0.01, 0.02, 0.04, 0.73)
	_scrim.size = PresentationLayout.CANVAS
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_panel = UiPanel.create(PANEL_RECT.position, PANEL_RECT.size, UiStyle.COMMAND).with_divider(29)
	add_child(_panel)
	_heading = UiStyle.make_label(_panel, Rect2(9, 7, 146, 10), "", 7, UiStyle.GOLD_BRIGHT, UiStyle.SEMIBOLD, 1)
	_funds = UiStyle.make_label(_panel, Rect2(157, 8, 56, 9), "", 5, UiStyle.TEXT_DIM, UiStyle.MEDIUM)
	_funds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_band = UiDecor.create("selection", Rect2(8, LIST_TOP - PANEL_RECT.position.y - 2, 205, ROW_HEIGHT))
	_panel.add_child(_band)
	for i in 4:
		_rows.append(UiStyle.make_label(_panel, Rect2(16, LIST_TOP - PANEL_RECT.position.y + i * ROW_HEIGHT, 194, 10), "", 6, UiStyle.TEXT, UiStyle.MEDIUM))
	_description = UiStyle.make_label(_panel, Rect2(10, 73, 202, 14), "", 5, UiStyle.TEXT_DIM)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_party = UiStyle.make_label(_panel, Rect2(10, 91, 202, 8), "", 5, UiStyle.GOLD_BRIGHT)
	_message = UiStyle.make_label(_panel, Rect2(10, 104, 202, 16), "", 5, UiStyle.TEXT_DIM)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false

func open(as_shop: bool) -> void:
	shopping = as_shop
	_items = ItemCatalog.all()
	cursor = 0
	target = 0
	_message.text = "Z buy · X leave" if shopping else "Left/Right choose Duelist · Z use · X leave"
	active = true
	visible = true
	_refresh()

func close() -> void:
	active = false
	visible = false
	closed.emit()

func _refresh() -> void:
	_heading.text = "GELL'S GOODS" if shopping else "FIELD BAG"
	_funds.text = "%d CROWNS" % GameState.crowns
	_band.position.y = LIST_TOP - PANEL_RECT.position.y - 2 + cursor * ROW_HEIGHT
	for i in _rows.size():
		_rows[i].visible = i < _items.size()
		if i < _items.size():
			var item: Dictionary = _items[i]
			var id := str(item.id)
			_rows[i].text = "%s   %d C   OWN %d" % [str(item.name), int(item.price), int(GameState.inventory.get(id, 0))] if shopping else "%s   x%d" % [str(item.name), int(GameState.inventory.get(id, 0))]
			_rows[i].add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT if i == cursor else UiStyle.TEXT)
	if _items.is_empty():
		_description.text = "No supplies available."
	else:
		_description.text = str(_items[cursor].description)
	var member: Dictionary = GameState.party[target] if target < GameState.party.size() else {}
	var maximum := int(GameData.get_class_record(str(member.get("class_id", "neutral"))).get("base_stats", {}).get("hp", 1))
	_party.text = "USE ON  ◀ %s  %d/%d HP ▶" % [str(member.get("name", "")), int(member.get("current_hp", maximum)), maximum] if not shopping else ""

func _unhandled_input(event: InputEvent) -> void:
	if not active or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("cancel"):
		close()
	elif event.is_action_pressed("move_up"):
		cursor = wrapi(cursor - 1, 0, maxi(1, _items.size()))
	elif event.is_action_pressed("move_down"):
		cursor = wrapi(cursor + 1, 0, maxi(1, _items.size()))
	elif not shopping and (event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
		target = wrapi(target + (-1 if event.is_action_pressed("move_left") else 1), 0, maxi(1, GameState.party.size()))
	elif event.is_action_pressed("interact") and not _items.is_empty():
		var id := str(_items[cursor].id)
		_message.text = GameState.purchase_item(id) if shopping else GameState.use_item(id, target)
		SaveManager.save_game()
	_refresh()
	get_viewport().set_input_as_handled()
