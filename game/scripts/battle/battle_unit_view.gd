extends Node2D
class_name BattleUnitView
## Placeholder rendering for one battle unit: class-coloured duelist
## chip, HP bar, and status pips (Brace, Hex, Awakened).

const TILE := 16

var unit: BattleUnit


func setup(unit_: BattleUnit) -> void:
	unit = unit_
	refresh()


func refresh() -> void:
	position = Vector2(unit.tile * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	visible = unit.is_alive()
	queue_redraw()


func _draw() -> void:
	if unit == null:
		return
	var body := PlaceholderPalette.class_color(unit.class_id)
	var outline := PlaceholderPalette.PLAYER_OUTLINE if unit.team == "player" else PlaceholderPalette.ENEMY_TINT
	if unit.acted:
		body = body.darkened(0.45)

	# Awakened Crest ring.
	if unit.awakened and unit.awakening_turns_left > 0:
		draw_rect(Rect2(-7, -8, 14, 15), Color(1.0, 0.85, 0.3, 0.9), false, 1.0)

	draw_rect(Rect2(-5, -3, 10, 9), outline)            # team outline
	draw_rect(Rect2(-4, -2, 8, 7), body)                # body
	draw_rect(Rect2(-3, -7, 6, 5), Color("e8c8a0"))     # head

	# HP bar.
	var ratio := float(unit.hp) / unit.max_hp
	draw_rect(Rect2(-6, 7, 12, 2), Color(0, 0, 0, 0.6))
	var hp_color := Color("57c26b") if ratio > 0.5 else (Color("e2b04a") if ratio > 0.25 else Color("e05555"))
	draw_rect(Rect2(-6, 7, 12 * ratio, 2), hp_color)

	# Status pips above the head.
	var pip_x := -6.0
	if unit.braced:
		draw_rect(Rect2(pip_x, -10, 3, 3), PlaceholderPalette.PANEL_BORDER)
		pip_x += 4
	if unit.has_status("hexed"):
		draw_rect(Rect2(pip_x, -10, 3, 3), PlaceholderPalette.TILE_CREST_NODE.lightened(0.3))
		pip_x += 4
