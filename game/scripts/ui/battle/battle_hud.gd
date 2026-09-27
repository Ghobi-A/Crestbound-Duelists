extends CanvasLayer
class_name BattleHud
## Battle UI composition: a title bar (encounter, objective, round) over
## the battlefield, a caption for resolution messages, and a command deck
## with one portrait card per active Duelist (built for 1-3 units), the
## action list, the description / target panel and a footer.

const DECK_TOP := 136.0
const CARD_AREA := Rect2(6, 3, 180, 31)
const MENU_X := 191.0
const INFO_RECT := Rect2(191, 3, 123, 31)
const CONTROLS := "Up/Down choose  Z confirm  X back"

var action_menu: ActionMenu
var round_preview: RoundPreview

var _chrome: BattleChrome
var _message_label: Label
var _message_plate: ColorRect
var _info_label: Label
var _info_panel: UiPanel
var _rows: Dictionary = {}   # BattleUnit -> UnitStatusPanel
var _rows_container: HBoxContainer
var _flash_rect: ColorRect
var _banner_label: Label
var _subphase := ""


func _ready() -> void:
	layer = 5
	_chrome = BattleChrome.new()
	add_child(_chrome)

	# Resolution captions float over the floor, never over the deck.
	_message_plate = ColorRect.new()
	_message_plate.color = Color(0.02, 0.03, 0.05, 0.72)
	_message_plate.position = Vector2(60, 123)
	_message_plate.size = Vector2(200, 9)
	_message_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_plate.visible = false
	add_child(_message_plate)
	_message_label = UiStyle.make_label(self, Rect2(60, 123.5, 200, 8), "", 5, UiStyle.TEXT, UiStyle.MEDIUM)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var bottom := Control.new()
	bottom.position = Vector2(0, 136)
	bottom.size = Vector2(320, PresentationLayout.DECK_HEIGHT)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

	_rows_container = HBoxContainer.new()
	_rows_container.position = CARD_AREA.position
	_rows_container.add_theme_constant_override("separation", 3)
	bottom.add_child(_rows_container)

	action_menu = ActionMenu.new()
	action_menu.position = Vector2(MENU_X, 3)
	action_menu.visible = false
	bottom.add_child(action_menu)

	# Target estimates take over the whole command column in violet, so
	# switching between choosing a move and a target never shifts layout.
	_info_panel = UiPanel.create(INFO_RECT.position, INFO_RECT.size, UiStyle.TARGET)
	_info_panel.visible = false
	bottom.add_child(_info_panel)
	_info_label = UiStyle.make_label(_info_panel, Rect2(5, 2, INFO_RECT.size.x - 10, INFO_RECT.size.y - 3), "", 5, UiStyle.TEXT)
	_info_label.add_theme_constant_override("line_spacing", -1)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	round_preview = RoundPreview.new()
	round_preview.position = Vector2((320.0 - RoundPreview.PANEL_SIZE.x) / 2.0, 24)
	add_child(round_preview)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.size = Vector2(320, 180)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	_banner_label = UiStyle.make_label(self, Rect2(0, 46, 320, 20), "", 12, UiStyle.GOLD_BRIGHT, UiStyle.SEMIBOLD, 2)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.visible = false
	_refresh_footer()


func build_rows(player_units: Array) -> void:
	var count := maxi(1, player_units.size())
	# Cards share the card area but never stretch past a comfortable width
	# for 1v1 and 2v2 encounters.
	var card_width := minf(92.0, (CARD_AREA.size.x - 3.0 * (count - 1)) / count)
	for unit in player_units:
		var row := UnitStatusPanel.new()
		row.custom_minimum_size = Vector2(card_width, CARD_AREA.size.y)
		row.size = row.custom_minimum_size
		_rows_container.add_child(row)
		row.bind(unit)
		_rows[unit] = row


func refresh_rows() -> void:
	for row in _rows.values():
		row.refresh()


func highlight_unit(unit: BattleUnit) -> void:
	for row_unit in _rows:
		_rows[row_unit].highlighted = row_unit == unit
		_rows[row_unit].refresh()


func mark_planned(unit: BattleUnit, planned: bool) -> void:
	if _rows.has(unit):
		_rows[unit].acted_marker = planned
		_rows[unit].refresh()


func set_title(text: String) -> void:
	_chrome.title = text
	_chrome.queue_redraw()


func set_phase(text: String) -> void:
	## "ROUND 2 — choose actions" puts the round top-right and the sub-phase
	## in the footer; a bare word (VICTORY) takes the round slot.
	var parts := text.split(" — ", false, 1)
	_chrome.round_text = parts[0]
	_subphase = parts[1] if parts.size() > 1 else ""
	_refresh_footer()
	_chrome.queue_redraw()


func set_objective(text: String) -> void:
	_chrome.objective = text
	_chrome.queue_redraw()


func set_footer_note(text: String) -> void:
	_chrome.footer_right = text
	_chrome.queue_redraw()


func _refresh_footer() -> void:
	_chrome.footer_left = (_subphase + "  ·  " + CONTROLS) if _subphase != "" else CONTROLS
	_chrome.queue_redraw()


func set_message(text: String) -> void:
	_message_label.text = text
	_message_plate.visible = text != ""
	if text != "":
		var width := minf(300.0, UiStyle.text_width(text, 5, UiStyle.MEDIUM) + 16.0)
		_message_plate.size.x = width
		_message_plate.position.x = (320.0 - width) / 2.0


func show_menu(unit: BattleUnit) -> void:
	_info_panel.visible = false
	action_menu.build_for(unit)
	action_menu.visible = true
	action_menu.modulate.a = 0.0
	action_menu.position.y = 5
	var reveal := create_tween().set_parallel()
	reveal.tween_property(action_menu, "position:y", 3.0, 0.12).set_ease(Tween.EASE_OUT)
	reveal.tween_property(action_menu, "modulate:a", 1.0, 0.12)


func hide_menu() -> void:
	action_menu.visible = false


func show_info(text: String) -> void:
	action_menu.visible = false
	_info_label.text = text
	_info_panel.visible = true
	_info_panel.modulate.a = 0.0
	_info_panel.position.y = INFO_RECT.position.y + 2
	var reveal := create_tween().set_parallel()
	reveal.tween_property(_info_panel, "position:y", INFO_RECT.position.y, 0.12).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_info_panel, "modulate:a", 1.0, 0.12)


func hide_info() -> void:
	_info_panel.visible = false


func play_awakening_banner(text: String, accent: Color) -> void:
	## Screen flash + banner used when a Crest awakens.
	_flash_rect.color = Color(accent.r, accent.g, accent.b, 0.0)
	var flash_tween := create_tween()
	flash_tween.tween_property(_flash_rect, "color:a", 0.45, 0.08)
	flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.35)

	_banner_label.text = text.to_upper()
	_banner_label.add_theme_color_override("font_color", accent.lightened(0.3))
	_banner_label.visible = true
	_banner_label.scale = Vector2(1.0, 0.2)
	_banner_label.pivot_offset = Vector2(160, 10)
	var banner_tween := create_tween()
	banner_tween.tween_property(_banner_label, "scale:y", 1.0, 0.12)
	banner_tween.tween_interval(1.0)
	banner_tween.tween_property(_banner_label, "scale:y", 0.0, 0.1)
	banner_tween.tween_callback(func(): _banner_label.visible = false)
