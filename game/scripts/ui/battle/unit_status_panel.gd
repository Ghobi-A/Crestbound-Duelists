extends Control
class_name UnitStatusPanel
## One compact status row for a player Duelist: name, HP bar, Crest
## Resonance meter, and state tags (BRACED / HEXED / stat mods /
## AWAKENED). The HUD stacks one per active party member.

const ROW_SIZE := Vector2(192, 17)

var unit: BattleUnit
var highlighted := false
var acted_marker := false


func _init() -> void:
	custom_minimum_size = ROW_SIZE
	size = ROW_SIZE


func bind(unit_: BattleUnit) -> void:
	unit = unit_
	refresh()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if unit == null:
		return
	var background := PlaceholderPalette.MOON_INDIGO
	if highlighted:
		background = PlaceholderPalette.MOON_SLATE.lightened(0.15)
	draw_rect(Rect2(Vector2.ZERO, ROW_SIZE), background)
	if highlighted:
		draw_rect(Rect2(Vector2.ZERO, ROW_SIZE), PlaceholderPalette.CREST_GOLD, false, 1.0)
	elif acted_marker:
		# A planned-but-not-active unit gets a quieter accent than the
		# acting unit's full gold border — a real visual, not just the
		# name's "*" suffix below.
		draw_rect(Rect2(Vector2.ZERO, Vector2(2, ROW_SIZE.y)), PlaceholderPalette.CREST_GOLD.darkened(0.35))

	var font := get_theme_default_font()
	var name_color := PlaceholderPalette.TEXT_MAIN if unit.is_alive() else PlaceholderPalette.TEXT_DIM
	var name_text := unit.display_name
	if acted_marker:
		name_text += " *"
	draw_string(font, Vector2(3, 8), name_text, HORIZONTAL_ALIGNMENT_LEFT, 96, 8, name_color)

	# HP bar.
	var hp_ratio := unit.hp_ratio()
	draw_rect(Rect2(100, 2, 60, 5), Color(0, 0, 0, 0.6))
	var hp_color := Color("57c26b") if hp_ratio > 0.5 else (Color("e2b04a") if hp_ratio > 0.25 else Color("e05555"))
	draw_rect(Rect2(100, 2, 60 * hp_ratio, 5), hp_color)
	draw_string(font, Vector2(163, 8), "%d" % unit.hp, HORIZONTAL_ALIGNMENT_LEFT, 28, 8, name_color)

	# Resonance meter (crestless units show no meter).
	if not unit.crest_record.is_empty():
		draw_rect(Rect2(100, 9, 60, 3), Color(0, 0, 0, 0.6))
		var resonance_color := PlaceholderPalette.TILE_CREST_NODE.lightened(0.35)
		if unit.awakened:
			resonance_color = Color(1.0, 0.85, 0.3)
		draw_rect(Rect2(100, 9, 60 * unit.resonance / 100.0, 3), resonance_color)

	# State tags.
	var tags: Array[String] = []
	if not unit.is_alive():
		tags.append("DOWN")
	if unit.awakened and unit.awakening_rounds_left > 0:
		tags.append("AWAKENED")
	if unit.is_braced():
		tags.append("BRACED")
	for status in unit.statuses:
		tags.append(str(status.name).to_upper())
	for mod in unit.stat_mods:
		tags.append("%s%+d" % [mod.stat.to_upper(), mod.amount])
	draw_string(font, Vector2(3, 15), " ".join(tags), HORIZONTAL_ALIGNMENT_LEFT, 186, 6, PlaceholderPalette.TEXT_WARN)
