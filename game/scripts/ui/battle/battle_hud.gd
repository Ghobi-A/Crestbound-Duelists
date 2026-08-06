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

	# UI container geometry below is the old 320x180-era layout doubled
	# uniformly — unlike battle sprite staging (which had to be solved
	# from actual art proportions, since art doesn't scale with the
	# canvas), a panel's position/size on a canvas that itself doubled
	# is correctly 2x its old value by construction. Font sizes are not
	# doubled (see docs/GODOT_SETUP.md — the bitmap font stays native).
	var top := ColorRect.new()
	top.color = PlaceholderPalette.MOON_SLATE
	top.size = Vector2(640, 24)
	add_child(top)
	# A gold underline separates the header from the battlefield, matching
	# the accent edge UiStyle.draw_panel puts on every other panel. Kept
	# as a plain ColorRect since the top bar isn't a custom-drawn Control.
	var top_accent := ColorRect.new()
	top_accent.color = PlaceholderPalette.CREST_GOLD
	top_accent.position = Vector2(0, 22)
	top_accent.size = Vector2(640, 2)
	top.add_child(top_accent)
	_phase_label = _label(top, Vector2(8, 2), Vector2(400, 20), PlaceholderPalette.TEXT_WARN)
	# Objective text is right-aligned and stops short of the icon, which
	# is pinned to the corner so it never moves as the text changes.
	_objective_label = _label(top, Vector2(280, 2), Vector2(320, 20), PlaceholderPalette.TEXT_DIM)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var objective_icon := UiIcons.make_texture("objective")
	if objective_icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = objective_icon
		icon_rect.position = Vector2(606, 4)
		icon_rect.modulate = PlaceholderPalette.CREST_GOLD
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(icon_rect)

	var message_strip := ColorRect.new()
	message_strip.color = Color(0, 0, 0, 0.55)
	# Flush against the top of the bottom panel (was 110 = old
	# BACKGROUND_HEIGHT(122) - 12; same relationship, new numbers).
	message_strip.position = Vector2(0, PresentationMetrics.BATTLE_BACKGROUND_HEIGHT - 24)
	message_strip.size = Vector2(640, 24)
	add_child(message_strip)
	_message_label = _label(message_strip, Vector2(8, 2), Vector2(624, 20), PlaceholderPalette.TEXT_MAIN)

	var bottom := ColorRect.new()
	bottom.color = PlaceholderPalette.MOON_SLATE
	# Position must track PresentationMetrics.BATTLE_BACKGROUND_HEIGHT — a
	# stale value here reopens the exact background/HUD seam
	# test_battle_staging.py's test_background_height_matches_hud_bottom_panel
	# exists to catch. The panel's internal content layout (status rows,
	# action menu, etc.) is unchanged/out of scope for this pass — only
	# this container's position/size, which is load-bearing for the seam.
	bottom.position = Vector2(0, PresentationMetrics.BATTLE_BACKGROUND_HEIGHT)
	bottom.size = Vector2(
		PresentationMetrics.CANVAS_SIZE.x,
		PresentationMetrics.CANVAS_SIZE.y - PresentationMetrics.BATTLE_BACKGROUND_HEIGHT
	)
	add_child(bottom)

	# ActionMenu/UnitStatusPanel/RoundPreview keep their original absolute
	# pixel footprint rather than being doubled: their content (row
	# spacing, description area) is sized against the native 8px font,
	# which is not changing in this pass, so inflating the frame around
	# it would only add dead space inside the panel, not real capacity —
	# what changes here is where these compact, content-sized widgets sit
	# within the much larger 640x360 canvas, not their own size.
	_rows_container = VBoxContainer.new()
	_rows_container.position = Vector2(8, 8)
	_rows_container.add_theme_constant_override("separation", 2)
	bottom.add_child(_rows_container)

	var action_menu_pos := Vector2(
		PresentationMetrics.CANVAS_SIZE.x - ActionMenu.MENU_SIZE.x - 8, 8
	)
	action_menu = ActionMenu.new()
	action_menu.position = action_menu_pos
	action_menu.visible = false
	bottom.add_child(action_menu)

	# The target/skill info panel shares the action menu's footprint and
	# takes the violet framing (target-facing, not command-facing) —
	# same size/position ActionMenu already occupies, so swapping between
	# the two never shifts anything else in the bottom panel.
	_info_panel = UiPanel.create(action_menu_pos, ActionMenu.MENU_SIZE, UiStyle.TARGET)
	_info_panel.visible = false
	bottom.add_child(_info_panel)
	# Width matters here: at 116 the longest enemy name wraps to a second
	# line and pushes the final stat row out of the panel entirely.
	_info_label = _label(_info_panel, Vector2(2, 3), Vector2(118, 52), PlaceholderPalette.TEXT_MAIN)
	_info_label.visible = false

	round_preview = RoundPreview.new()
	round_preview.position = Vector2(
		(PresentationMetrics.CANVAS_SIZE.x - RoundPreview.PANEL_SIZE.x) / 2.0, 32
	)
	add_child(round_preview)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.size = Vector2(PresentationMetrics.CANVAS_SIZE)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	_banner_label = _label(self, Vector2(0, 92), Vector2(640, 20), PlaceholderPalette.CREST_GOLD_BRIGHT)
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


func hide_menu() -> void:
	action_menu.visible = false


func show_info(text: String) -> void:
	action_menu.visible = false
	_info_label.text = text
	_info_label.visible = true
	_info_panel.visible = true


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
	_banner_label.pivot_offset = Vector2(320, 10)
	var banner_tween := create_tween()
	banner_tween.tween_property(_banner_label, "scale:y", 1.0, 0.12)
	banner_tween.tween_interval(1.0)
	banner_tween.tween_property(_banner_label, "scale:y", 0.0, 0.1)
	banner_tween.tween_callback(func(): _banner_label.visible = false)
