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
var _rows: Dictionary = {}   # BattleUnit -> UnitStatusPanel
var _rows_container: VBoxContainer
var _flash_rect: ColorRect
var _banner_label: Label


func _ready() -> void:
	layer = 5

	var top := ColorRect.new()
	top.color = PlaceholderPalette.BG_PANEL
	top.size = Vector2(320, 12)
	add_child(top)
	_phase_label = _label(top, Vector2(4, 1), Vector2(200, 10), PlaceholderPalette.TEXT_WARN)
	_objective_label = _label(top, Vector2(150, 1), Vector2(166, 10), PlaceholderPalette.TEXT_DIM)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var message_strip := ColorRect.new()
	message_strip.color = Color(0, 0, 0, 0.55)
	message_strip.position = Vector2(0, 110)
	message_strip.size = Vector2(320, 12)
	add_child(message_strip)
	_message_label = _label(message_strip, Vector2(4, 1), Vector2(312, 10), PlaceholderPalette.TEXT_MAIN)

	var bottom := ColorRect.new()
	bottom.color = PlaceholderPalette.BG_DARK
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

	_info_label = _label(bottom, Vector2(198, 3), Vector2(120, 54), PlaceholderPalette.TEXT_MAIN)
	_info_label.visible = false

	round_preview = RoundPreview.new()
	round_preview.position = Vector2(70, 16)
	add_child(round_preview)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.size = Vector2(320, 180)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	_banner_label = _label(self, Vector2(0, 46), Vector2(320, 20), Color(1.0, 0.85, 0.3))
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
	action_menu.build_for(unit)
	action_menu.visible = true


func hide_menu() -> void:
	action_menu.visible = false


func show_info(text: String) -> void:
	action_menu.visible = false
	_info_label.text = text
	_info_label.visible = true


func hide_info() -> void:
	_info_label.visible = false


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
