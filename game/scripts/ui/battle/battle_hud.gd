extends CanvasLayer
class_name BattleHud
## Battle UI composition over a full-bleed battlefield: a turn-order rail
## of portrait diamonds (top left), the encounter title box and command
## list (top right), a caption for resolution messages, and floating party
## cards (built for 1-3 units) beside the description / target panel.

const CARD_AREA := Rect2(6, 0, 186, 31)
const MENU_POS := Vector2(240, 25)
const INFO_RECT := Rect2(198, 0, 116, 31)
const RAIL := Rect2(6, 3, 222, 26)
const CONTROLS := ""

var action_menu: ActionMenu
var round_preview: RoundPreview

var _chrome: BattleChrome
var _message_label: Label
var _message_plate: ColorRect
var _info_label: Label
var _info_panel: UiPanel
var _rows: Dictionary = {}   # BattleUnit -> UnitStatusPanel
var _tokens: Dictionary = {} # BattleUnit -> TurnToken
var _turn_order: Array = []  # BattleUnit, projected initiative
var _acting: BattleUnit
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
	_message_plate.position = Vector2(60, 131)
	_message_plate.size = Vector2(200, 9)
	_message_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_plate.visible = false
	add_child(_message_plate)
	_message_label = UiStyle.make_label(self, Rect2(60, 131.5, 200, 8), "", 5, UiStyle.TEXT, UiStyle.MEDIUM)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var bottom := Control.new()
	bottom.position = Vector2(0, 140)
	bottom.size = Vector2(320, PresentationLayout.DECK_HEIGHT)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

	_rows_container = HBoxContainer.new()
	_rows_container.position = CARD_AREA.position
	_rows_container.add_theme_constant_override("separation", 3)
	bottom.add_child(_rows_container)

	action_menu = ActionMenu.new()
	action_menu.position = MENU_POS
	action_menu.visible = false
	add_child(action_menu)

	# The focused command's description, or the target estimate in violet,
	# share one panel beside the party cards so layout never shifts.
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
	# A duel gets one substantial centered card; full parties divide the
	# same bounded area without reserving blank slots for absent members.
	var card_width := minf(130.0, (CARD_AREA.size.x - 3.0 * (count - 1)) / count)
	_rows_container.position.x = CARD_AREA.position.x + (CARD_AREA.size.x - card_width * count - 3.0 * (count - 1)) / 2.0
	for unit in player_units:
		var row := UnitStatusPanel.new()
		row.custom_minimum_size = Vector2(card_width, CARD_AREA.size.y)
		row.size = row.custom_minimum_size
		_rows_container.add_child(row)
		row.bind(unit)
		_rows[unit] = row


func build_turn_rail(units: Array) -> void:
	for unit in units:
		var token := TurnToken.new()
		add_child(token)
		token.bind(unit)
		_tokens[unit] = token
	set_turn_order(units)


func set_turn_order(order: Array) -> void:
	## `order` comes from BattleResolver.projected_order; fallen units keep a
	## crossed-out token at the end of the rail.
	_turn_order = order.duplicate()
	for unit in _tokens:
		if not _turn_order.has(unit):
			_turn_order.append(unit)
	_layout_rail()


func _layout_rail() -> void:
	## Allies run left from the lead diamond, enemies sit right-aligned on
	## the far side of the round marker; each side keeps projected order.
	var lead: BattleUnit = _acting if _acting != null and _tokens.has(_acting) else null
	for unit in _tokens:
		_tokens[unit].set_lead(unit == lead)
	if lead != null:
		_tokens[lead].position = RAIL.position + Vector2(0, 1)
	var allies := _turn_order.filter(func(unit): return unit != lead and unit.team == "player")
	var enemies := _turn_order.filter(func(unit): return unit.team != "player")
	var stride := TurnToken.SMALL + 5.0
	var start := RAIL.position.x + TurnToken.LEAD + 6.0
	var y := RAIL.position.y + 6.5
	for i in allies.size():
		_tokens[allies[i]].position = Vector2(roundf(start + i * stride), y)
	var enemy_start := RAIL.end.x - TurnToken.SMALL - maxf(0.0, enemies.size() - 1.0) * stride
	for i in enemies.size():
		_tokens[enemies[i]].position = Vector2(roundf(enemy_start + i * stride), y)
	var ally_end := start + maxf(0.0, allies.size() - 1.0) * stride + TurnToken.SMALL
	_chrome.rail_from = RAIL.position.x + (TurnToken.LEAD if lead != null else 0.0)
	_chrome.rail_mid = roundf((ally_end + enemy_start) / 2.0)
	_chrome.rail_to = RAIL.end.x + 3.0
	_chrome.queue_redraw()


func highlight_enemy(unit: BattleUnit) -> void:
	for token_unit in _tokens:
		_tokens[token_unit].selected = token_unit == unit
		_tokens[token_unit].refresh()


func refresh_rows() -> void:
	for row in _rows.values():
		row.refresh()
	for token in _tokens.values():
		token.refresh()


func highlight_unit(unit: BattleUnit) -> void:
	for row_unit in _rows:
		_rows[row_unit].highlighted = row_unit == unit
		_rows[row_unit].refresh()
	# The commanded Duelist leads the rail in a large diamond.
	_acting = unit
	for token_unit in _tokens:
		_tokens[token_unit].acting = token_unit == unit
	if not _tokens.is_empty():
		_layout_rail()


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
	_chrome.footer_left = _subphase
	_chrome.queue_redraw()


func set_message(text: String) -> void:
	_message_label.text = text
	_message_plate.visible = text != ""
	if text != "":
		var width := minf(300.0, UiStyle.text_width(text, 5, UiStyle.MEDIUM) + 16.0)
		_message_plate.size.x = width
		_message_plate.position.x = (320.0 - width) / 2.0


func show_menu(unit: BattleUnit, allow_flee := false) -> void:
	action_menu.build_for(unit, allow_flee)
	if not action_menu.cursor_moved.is_connected(_show_description):
		action_menu.cursor_moved.connect(_show_description)
	action_menu.visible = true
	action_menu.modulate.a = 0.0
	action_menu.position.y = MENU_POS.y + 2
	var reveal := create_tween().set_parallel()
	reveal.tween_property(action_menu, "position:y", MENU_POS.y, 0.12).set_ease(Tween.EASE_OUT)
	reveal.tween_property(action_menu, "modulate:a", 1.0, 0.12)
	_show_description()


func _show_description() -> void:
	## The focused command's description, gold heading over dim detail.
	_info_panel.set_role(UiStyle.NEUTRAL)
	_info_label.text = str(action_menu.current_entry().description)
	_info_panel.visible = true


func hide_menu() -> void:
	action_menu.visible = false
	_info_panel.visible = false


func show_info(text: String) -> void:
	action_menu.visible = false
	_info_panel.set_role(UiStyle.TARGET)
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
