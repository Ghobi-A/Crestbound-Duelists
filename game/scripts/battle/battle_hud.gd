extends CanvasLayer
class_name BattleHud
## Battle UI: phase/objective strip, selected-unit panel, action menu,
## and target preview. Pure presentation — the controller feeds it state.

var _phase_label: Label
var _objective_label: Label
var _unit_panel: ColorRect
var _unit_label: Label
var _menu_panel: ColorRect
var _menu_label: Label
var _preview_label: Label
var _message_label: Label


func _ready() -> void:
	layer = 5

	var top := ColorRect.new()
	top.color = PlaceholderPalette.BG_PANEL
	top.position = Vector2(0, 0)
	top.size = Vector2(320, 14)
	add_child(top)

	_phase_label = _label(top, Vector2(4, 2), Vector2(180, 10), PlaceholderPalette.TEXT_WARN)
	_objective_label = _label(top, Vector2(150, 2), Vector2(166, 10), PlaceholderPalette.TEXT_DIM)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_unit_panel = ColorRect.new()
	_unit_panel.color = PlaceholderPalette.BG_PANEL
	_unit_panel.position = Vector2(196, 18)
	_unit_panel.size = Vector2(120, 92)
	add_child(_unit_panel)
	_unit_label = _label(_unit_panel, Vector2(4, 2), Vector2(112, 88), PlaceholderPalette.TEXT_MAIN)

	_menu_panel = ColorRect.new()
	_menu_panel.color = PlaceholderPalette.BG_PANEL
	_menu_panel.position = Vector2(196, 114)
	_menu_panel.size = Vector2(120, 62)
	add_child(_menu_panel)
	_menu_label = _label(_menu_panel, Vector2(4, 2), Vector2(112, 58), PlaceholderPalette.TEXT_MAIN)

	_preview_label = _label(self, Vector2(8, 150), Vector2(184, 26), PlaceholderPalette.TEXT_WARN)
	_message_label = _label(self, Vector2(8, 18), Vector2(184, 12), PlaceholderPalette.TEXT_WARN)


func _label(parent: Node, top_left: Vector2, size_: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.position = top_left
	label.size = size_
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func set_phase(text: String) -> void:
	_phase_label.text = text


func set_objective(text: String) -> void:
	_objective_label.text = text


func set_message(text: String) -> void:
	_message_label.text = text


func show_unit(unit: BattleUnit, grid: BattleGrid) -> void:
	if unit == null:
		_unit_label.text = ""
		return
	var lines: Array[String] = []
	lines.append("%s" % unit.display_name)
	lines.append("%s  HP %d/%d" % [unit.class_record.get("name", unit.class_id), unit.hp, unit.max_hp])
	if not unit.crest_record.is_empty():
		var crest_line: String = unit.crest_record.get("name", "")
		if unit.awakened and unit.awakening_turns_left > 0:
			crest_line += " [AWAKENED %d]" % unit.awakening_turns_left
		lines.append(crest_line)
	var states: Array[String] = []
	if unit.braced:
		states.append("BRACED")
	for status in unit.statuses:
		states.append("%s(%d)" % [str(status.name).to_upper(), status.turns])
	for mod in unit.stat_mods:
		states.append("%s%+d(%d)" % [mod.stat, mod.amount, mod.turns])
	if not states.is_empty():
		lines.append(" ".join(states))
	var terrain := grid.terrain_at(unit.tile)
	if int(terrain.get("defense_bonus", 0)) != 0 or int(terrain.get("resistance_bonus", 0)) != 0:
		lines.append("%s +%d DEF +%d RES" % [
			terrain.get("name", ""), int(terrain.get("defense_bonus", 0)),
			int(terrain.get("resistance_bonus", 0)),
		])
	_unit_label.text = "\n".join(lines)


func show_menu(entries: Array, selected_index: int) -> void:
	## entries: [{label: String, enabled: bool, note: String}]
	var lines: Array[String] = []
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var cursor: String = "> " if i == selected_index else "  "
		var text: String = cursor + str(entry.label)
		if not entry.get("enabled", true):
			text += "  [%s]" % entry.get("note", "X")
		lines.append(text)
	_menu_label.text = "\n".join(lines)


func clear_menu() -> void:
	_menu_label.text = ""


func show_preview(text: String) -> void:
	_preview_label.text = text


func clear_preview() -> void:
	_preview_label.text = ""
