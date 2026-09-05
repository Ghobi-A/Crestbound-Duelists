extends CanvasLayer
class_name BattleHud
## Battle UI composition: top phase strip, message line, per-Duelist
## status rows (built dynamically for 1-3 active party members), and a
## contextual right panel hosting the action menu / target info.

var action_menu: ActionMenu
var round_preview: RoundPreview

var _phase_label: Label
var _objective_label: Label
var _message_label: Label
var _info_label: Label
var _info_panel: UiPanel
var _rows: Dictionary = {}   # BattleUnit -> UnitStatusPanel
var _rows_container: VBoxContainer
var _flash_rect: ColorRect
var _banner_label: Label


func _ready() -> void:
	layer = 5

	var top := ColorRect.new()
	top.color = PlaceholderPalette.MOON_SLATE
	top.size = Vector2(320, 12)
	add_child(top)
	# A gold underline separates the header from the battlefield, matching
	# the accent edge UiStyle.draw_panel puts on every other panel. Kept
	# as a plain ColorRect since the top bar isn't a custom-drawn Control.
	var top_accent := ColorRect.new()
	top_accent.color = PlaceholderPalette.CREST_GOLD
	top_accent.position = Vector2(0, 11)
	top_accent.size = Vector2(320, 1)
	top.add_child(top_accent)
	_phase_label = _label(top, Vector2(4, 1), Vector2(200, 10), PlaceholderPalette.TEXT_WARN)
	# Objective text is right-aligned and stops short of the icon, which
	# is pinned to the corner so it never moves as the text changes.
	_objective_label = _label(top, Vector2(140, 1), Vector2(160, 10), PlaceholderPalette.TEXT_DIM)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var objective_icon := UiIcons.make_texture("objective")
	if objective_icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = objective_icon
		icon_rect.position = Vector2(303, 2)
		icon_rect.modulate = PlaceholderPalette.CREST_GOLD
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(icon_rect)

	var message_strip := ColorRect.new()
	message_strip.color = Color(0, 0, 0, 0.55)
	message_strip.position = Vector2(0, 110)
	message_strip.size = Vector2(320, 12)
	add_child(message_strip)
	_message_label = _label(message_strip, Vector2(4, 1), Vector2(312, 10), PlaceholderPalette.TEXT_MAIN)

	var bottom := ColorRect.new()
	bottom.color = PlaceholderPalette.MOON_SLATE
	bottom.position = Vector2(0, 122)
	bottom.size = Vector2(320, 58)
	add_child(bottom)

	_rows_container = VBoxContainer.new()
	_rows_container.position = Vector2(2, 2)
	_rows_container.add_theme_constant_override("separation", 1)
	bottom.add_child(_rows_container)

	action_menu = ActionMenu.new()
	action_menu.position = Vector2(196, 1)
	action_menu.visible = false
	bottom.add_child(action_menu)

	# The target/skill info panel shares the action menu's footprint and
	# takes the violet framing (target-facing, not command-facing) —
	# same size/position ActionMenu already occupies, so swapping between
	# the two never shifts anything else in the bottom panel.
	_info_panel = UiPanel.create(Vector2(196, 1), ActionMenu.MENU_SIZE, UiStyle.TARGET)
	_info_panel.visible = false
	bottom.add_child(_info_panel)
	# Width matters here: at 116 the longest enemy name wraps to a second
	# line and pushes the final stat row out of the panel entirely.
	_info_label = _label(_info_panel, Vector2(2, 3), Vector2(118, 52), PlaceholderPalette.TEXT_MAIN)
	_info_label.visible = false

	round_preview = RoundPreview.new()
	# Centred on the 320px canvas: (320 - RoundPreview.PANEL_SIZE.x) / 2.
	round_preview.position = Vector2((320.0 - RoundPreview.PANEL_SIZE.x) / 2.0, 16)
	add_child(round_preview)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.size = Vector2(320, 180)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	_banner_label = _label(self, Vector2(0, 46), Vector2(320, 20), PlaceholderPalette.CREST_GOLD_BRIGHT)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 12)
	_banner_label.visible = false


func _label(parent: Node, top_left: Vector2, size_: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.position = top_left
	label.size = size_
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func build_rows(player_units: Array) -> void:
	for unit in player_units:
		var row := UnitStatusPanel.new()
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


func set_phase(text: String) -> void:
	_phase_label.text = text


func set_objective(text: String) -> void:
	_objective_label.text = text


func set_message(text: String) -> void:
	_message_label.text = text


func show_menu(unit: BattleUnit) -> void:
	_info_label.visible = false
	_info_panel.visible = false
	action_menu.build_for(unit)
	action_menu.visible = true
	action_menu.modulate.a = 0.0
	action_menu.position.x = 200
	var reveal := create_tween().set_parallel()
	reveal.tween_property(action_menu, "position:x", 196.0, 0.08)
	reveal.tween_property(action_menu, "modulate:a", 1.0, 0.08)


func hide_menu() -> void:
	action_menu.visible = false


func show_info(text: String) -> void:
	action_menu.visible = false
	_info_label.text = text
	_info_label.visible = true
	_info_panel.visible = true
	_info_panel.modulate.a = 0.0
	_info_panel.position.x = 192
	var reveal := create_tween().set_parallel()
	reveal.tween_property(_info_panel, "position:x", 196.0, 0.08)
	reveal.tween_property(_info_panel, "modulate:a", 1.0, 0.08)


func hide_info() -> void:
	_info_label.visible = false
	_info_panel.visible = false


func play_awakening_banner(text: String, accent: Color) -> void:
	## Screen flash + banner used when a Crest awakens.
	_flash_rect.color = Color(accent.r, accent.g, accent.b, 0.0)
	var flash_tween := create_tween()
	flash_tween.tween_property(_flash_rect, "color:a", 0.45, 0.08)
	flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.35)

	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", accent.lightened(0.3))
	_banner_label.visible = true
	_banner_label.scale = Vector2(1.0, 0.2)
	_banner_label.pivot_offset = Vector2(160, 10)
	var banner_tween := create_tween()
	banner_tween.tween_property(_banner_label, "scale:y", 1.0, 0.12)
	banner_tween.tween_interval(1.0)
	banner_tween.tween_property(_banner_label, "scale:y", 0.0, 0.1)
	banner_tween.tween_callback(func(): _banner_label.visible = false)
