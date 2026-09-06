extends Control
class_name UnitStatusPanel
## Responsive character card; all values are read from the authoritative unit.
const ROW_SIZE := Vector2(192, 54)
var unit: BattleUnit
var highlighted := false
var acted_marker := false
var _portrait: TextureRect


func _init() -> void:
	custom_minimum_size = ROW_SIZE
	size = ROW_SIZE
	clip_contents = true


func bind(unit_: BattleUnit) -> void:
	unit = unit_
	_portrait = TextureRect.new()
	PresentationLayout.texture_box(_portrait, Rect2(4, 13, 18, 22))
	add_child(_portrait)
	CharacterPresentation.apply_portrait(_portrait, unit.sprite_key())
	refresh()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if unit == null:
		return
	UiStyle.draw_panel(self, Rect2(Vector2.ZERO, size), UiStyle.COMMAND if highlighted else UiStyle.NEUTRAL)
	var font := get_theme_default_font()
	var name := unit.display_name.trim_prefix("Warden ")
	var ink := PlaceholderPalette.TEXT_MAIN if unit.is_alive() else PlaceholderPalette.TEXT_DIM
	draw_string(font, Vector2(4, 10), name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 8, ink)
	draw_string(font, Vector2(25, 22), str(unit.hp), HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 8, ink)
	draw_string(font, Vector2(25, 32), "HP", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 6, PlaceholderPalette.TEXT_DIM)
	var bar_width := size.x - 8
	draw_rect(Rect2(4, 37, bar_width, 4), Color("060a10"))
	var health_colour := Color("b95d60") if unit.hp_ratio() > 0.25 else Color("e09655")
	draw_rect(Rect2(4, 37, bar_width * unit.hp_ratio(), 4), health_colour)
	if not unit.crest_record.is_empty():
		draw_rect(Rect2(4, 44, bar_width, 3), Color("060a10"))
		draw_rect(Rect2(4, 44, bar_width * clampf(unit.resonance / 100.0, 0, 1), 3), PlaceholderPalette.SPECTRAL_VIOLET)
	var tags: Array[String] = []
	if not unit.is_alive(): tags.append("DOWN")
	if unit.is_braced(): tags.append("BRACE")
	if unit.has_status("hexed"): tags.append("HEX")
	if unit.awakened: tags.append("AWAKE")
	if acted_marker: tags.append("READY")
	draw_string(font, Vector2(4, 53), " ".join(tags), HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 6, PlaceholderPalette.TEXT_WARN)
	var details: Array[String] = [unit.display_name, "HP %d / %d" % [unit.hp, unit.max_hp], "Resonance %d" % unit.resonance]
	for status in unit.statuses: details.append(str(status.name))
	for modifier in unit.stat_mods: details.append("%s %+d" % [modifier.stat, modifier.amount])
	tooltip_text = "\n".join(details)
