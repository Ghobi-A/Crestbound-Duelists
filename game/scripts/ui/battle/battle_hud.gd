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
var _info_panel: _ContextColumn


class _ContextColumn:
	extends Control
	## The target-information column. Violet, because it describes what an
	## action affects rather than what the player commands.
	func _draw() -> void:
		UiStyle.draw_column_rule(self, Rect2(Vector2.ZERO, size), UiStyle.TARGET)
var _rows: Dictionary = {}   # BattleUnit -> UnitStatusPanel
var _rows_container: HBoxContainer
var _flash_rect: ColorRect
var _banner_label: Label


## Interior padding and the gap between the card strip and the
## contextual panel. Everything below positions against these and
## against PresentationLayout, never against a literal canvas size.
const PAD := 12.0
const GUTTER := 16.0
## The contextual panel (action menu / target info) occupies the right
## third of the HUD; the card strip takes the rest. Cards carry a
## smaller share of the screen than they did at 320x180, where they ran
## the full width of a 58px bar on a 180px canvas.
const CONTEXT_PANEL_WIDTH := 420.0


func _ready() -> void:
	layer = 5
	var canvas := PresentationLayout.CANVAS
	var hud := PresentationLayout.hud_rect()

	# Header: a downward-fading scrim over the artwork rather than an
	# opaque bar, so the top of the Hollow Court plate stays visible.
	var top := _Chrome.new()
	top.kind = _Chrome.HEADER
	top.size = Vector2(canvas.x, PresentationLayout.TOP_BAR_HEIGHT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var bar_text_height := Typography.line_height(Typography.Role.HEADING) * 1.35
	_phase_label = _label(top, Vector2(PAD, (top.size.y - bar_text_height) * 0.5),
		Vector2(canvas.x * 0.42, bar_text_height), PlaceholderPalette.CREST_GOLD_BRIGHT, Typography.Role.HEADING)
	_phase_label.clip_text = true
	_phase_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Objective text is right-aligned and stops short of the icon, which
	# is pinned to the corner so it never moves as the text changes.
	var objective_icon := UiIcons.make_texture("objective")
	var icon_side := UiIcons.display_size() if objective_icon != null else 0.0
	var objective_right := canvas.x - PAD - icon_side - (PAD if icon_side > 0.0 else 0.0)
	_objective_label = _label(top, Vector2(canvas.x * 0.45, (top.size.y - bar_text_height) * 0.5),
		Vector2(objective_right - canvas.x * 0.45, bar_text_height),
		PlaceholderPalette.TEXT_DIM, Typography.Role.SECONDARY)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective_label.clip_text = true
	if objective_icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = objective_icon
		PresentationLayout.texture_box(icon_rect, Rect2(
			canvas.x - PAD - icon_side, (top.size.y - icon_side) * 0.5, icon_side, icon_side))
		PresentationLayout.use_pixel_art_filter(icon_rect)
		icon_rect.modulate = PlaceholderPalette.CREST_GOLD
		top.add_child(icon_rect)

	var message_strip := _Chrome.new()
	message_strip.kind = _Chrome.MESSAGE
	message_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_strip.position = Vector2(0, hud.position.y - PresentationLayout.MESSAGE_STRIP_HEIGHT)
	message_strip.size = Vector2(canvas.x, PresentationLayout.MESSAGE_STRIP_HEIGHT)
	add_child(message_strip)
	var message_line := Typography.line_height(Typography.Role.BODY) * 1.35
	_message_label = _label(message_strip, Vector2(PAD, (message_strip.size.y - message_line) * 0.5),
		Vector2(canvas.x - PAD * 2, message_line), PlaceholderPalette.TEXT_MAIN, Typography.Role.BODY)

	var bottom := _Chrome.new()
	bottom.kind = _Chrome.HUD
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.position = hud.position
	bottom.size = hud.size
	add_child(bottom)

	var context_x := hud.size.x - PAD - CONTEXT_PANEL_WIDTH
	_rows_container = HBoxContainer.new()
	_rows_container.position = Vector2(PAD, PAD)
	_rows_container.add_theme_constant_override("separation", int(GUTTER * 0.5))
	bottom.add_child(_rows_container)

	var context_rect := Rect2(context_x, PAD, CONTEXT_PANEL_WIDTH, hud.size.y - PAD * 2)
	action_menu = ActionMenu.new()
	action_menu.position = context_rect.position
	action_menu.visible = false
	bottom.add_child(action_menu)

	# The target/skill info panel shares the action menu's footprint and
	# takes the violet framing (target-facing, not command-facing), so
	# swapping between the two never shifts anything else in the HUD.
	# Same treatment as the action menu it replaces on screen: a column
	# rule rather than a second filled box inside the HUD band.
	_info_panel = _ContextColumn.new()
	_info_panel.position = context_rect.position
	_info_panel.size = context_rect.size
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.visible = false
	bottom.add_child(_info_panel)
	_info_label = _label(_info_panel, Vector2(PAD, PAD),
		context_rect.size - Vector2(PAD * 2, PAD * 2), PlaceholderPalette.TEXT_MAIN, Typography.Role.BODY)
	_info_label.visible = false

	round_preview = RoundPreview.new()
	round_preview.position = Vector2(
		(canvas.x - RoundPreview.PANEL_SIZE.x) * 0.5,
		(PresentationLayout.BATTLE_HEIGHT - RoundPreview.PANEL_SIZE.y) * 0.5)
	add_child(round_preview)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.size = canvas
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	_banner_label = _label(self, Vector2(0, PresentationLayout.BATTLE_HEIGHT * 0.36),
		Vector2(canvas.x, Typography.line_height(Typography.Role.DISPLAY) * 1.4),
		PlaceholderPalette.CREST_GOLD_BRIGHT, Typography.Role.DISPLAY)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.visible = false


class _Chrome:
	extends Control
	## The HUD's own background bands. Custom-drawn rather than ColorRects
	## because each is a fade over artwork, not a flat fill.
	const HEADER := 0
	const MESSAGE := 1
	const HUD := 2

	var kind := HUD

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		match kind:
			HEADER:
				# Fades downward, so it is darkest under the text and
				# gone by the time it reaches the battlefield.
				var steps := 8
				for i in steps:
					var t := 1.0 - float(i) / float(steps)
					draw_rect(Rect2(Vector2(0, size.y * float(i) / float(steps)),
						Vector2(size.x, size.y / float(steps) + 1.0)),
						Color(0.02, 0.03, 0.05, 0.80 * t * t))
				draw_rect(Rect2(Vector2(0, size.y - UiStyle.LINE), Vector2(size.x, UiStyle.LINE)),
					PlaceholderPalette.CREST_GOLD)
			MESSAGE:
				UiStyle.draw_scrim(self, rect, 0.62)
			HUD:
				# The HUD band is the one place that stays near-opaque:
				# it carries the densest text in the game and sits over
				# the busiest part of the plate.
				UiStyle.draw_surface(self, rect,
					Color(0.043, 0.055, 0.086, 0.90), Color(0.024, 0.031, 0.051, 0.97), false)


func _context_x() -> float:
	## Resting x of the contextual panel, shared by the action menu and
	## the target info panel so they occupy exactly the same footprint.
	return PresentationLayout.CANVAS.x - PAD - CONTEXT_PANEL_WIDTH


func _label(parent: Node, top_left: Vector2, size_: Vector2, color: Color,
		role := Typography.Role.BODY) -> Label:
	var label := Label.new()
	label.position = top_left
	label.size = size_
	Typography.apply(label, role, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	parent.add_child(label)
	return label


func build_rows(player_units: Array) -> void:
	var strip_width := PresentationLayout.CANVAS.x - PAD * 3 - CONTEXT_PANEL_WIDTH
	var separation := GUTTER * 0.5
	for unit in player_units:
		var row := UnitStatusPanel.new()
		var gaps := separation * maxf(0, player_units.size() - 1)
		var card_width := (strip_width - gaps) / maxf(1, player_units.size())
		row.custom_minimum_size = Vector2(card_width, PresentationLayout.HUD_HEIGHT - PAD * 2)
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
	var rest_x := _context_x()
	action_menu.position.x = rest_x + GUTTER
	var reveal := create_tween().set_parallel()
	reveal.tween_property(action_menu, "position:x", rest_x, 0.08)
	reveal.tween_property(action_menu, "modulate:a", 1.0, 0.08)


func hide_menu() -> void:
	action_menu.visible = false


func show_info(text: String) -> void:
	action_menu.visible = false
	_info_label.text = text
	_info_label.visible = true
	_info_panel.visible = true
	_info_panel.modulate.a = 0.0
	var rest_x := _context_x()
	_info_panel.position.x = rest_x - GUTTER
	var reveal := create_tween().set_parallel()
	reveal.tween_property(_info_panel, "position:x", rest_x, 0.08)
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
	_banner_label.pivot_offset = _banner_label.size * 0.5
	var banner_tween := create_tween()
	banner_tween.tween_property(_banner_label, "scale:y", 1.0, 0.12)
	banner_tween.tween_interval(1.0)
	banner_tween.tween_property(_banner_label, "scale:y", 0.0, 0.1)
	banner_tween.tween_callback(func(): _banner_label.visible = false)
