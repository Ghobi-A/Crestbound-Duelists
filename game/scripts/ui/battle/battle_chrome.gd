extends Control
class_name BattleChrome
## Static framing for the battle screen, drawn under the interactive HUD:
## the turn-order rail's line, the encounter title box (title, round,
## objective), the fade from the floor under the party cards, and the
## footer hints. Presentation only; every string is supplied by BattleHud.

const TITLE_BOX := Rect2(240, 3, 76, 19)

var title := ""
var round_text := ""
var objective := ""
var footer_left := ""
var footer_right := ""
var rail_from := 6.0
var rail_to := 230.0


func _init() -> void:
	size = PresentationLayout.CANVAS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var width := PresentationLayout.CANVAS.x
	var deck := float(PresentationLayout.BATTLE_HEIGHT)
	var footer := float(PresentationLayout.FOOTER_TOP)

	# A soft sky shade keeps the rail and title legible over bright art.
	UiStyle.draw_vignette_band(self, Rect2(0, 0, width, 42), 0.62, 0.0, 12)

	# Turn-order rail: a lit line threading the tokens, with node pips.
	var rail_y := 3.0 + 6.5 + TurnToken.SMALL / 2.0
	draw_rect(Rect2(rail_from, rail_y - 0.35, rail_to - rail_from, 0.7), Color(UiStyle.GOLD, 0.55))
	draw_rect(Rect2(rail_from, rail_y - 1.0, rail_to - rail_from, 2.0), Color(UiStyle.GOLD, 0.08))
	UiStyle.draw_ornament(self, Vector2(rail_to + 2.0, rail_y), 2.6, UiStyle.GOLD_BRIGHT)
	if objective != "":
		UiStyle.draw_glyph(self, "objective", Vector2(10, 35.0), 1.8, UiStyle.GOLD)
		UiStyle.draw_text(self, Vector2(14.5, 37.0), objective.to_upper(), 5, UiStyle.TEXT_DIM, 120, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.REGULAR, 0.5)

	# Encounter title box.
	UiStyle.draw_panel(self, TITLE_BOX, UiStyle.NEUTRAL, false)
	var heading := title.to_upper()
	var tracking := 1.4 if UiStyle.text_width(heading, 6, UiStyle.MEDIUM, 1.4) <= TITLE_BOX.size.x - 8 else 0.4
	UiStyle.draw_text(self, TITLE_BOX.position + Vector2(5, 7.6), heading, 6, UiStyle.TEXT, TITLE_BOX.size.x - 8, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.MEDIUM, tracking)
	UiStyle.draw_text(self, TITLE_BOX.position + Vector2(5, 15.4), round_text.to_upper(), 5, UiStyle.TEXT_DIM, TITLE_BOX.size.x - 8, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.REGULAR, 0.8)

	# The floor darkens under the party cards instead of meeting a hard deck.
	UiStyle.draw_vignette_band(self, Rect2(0, deck - 14, width, 180 - deck + 14), 0.0, 0.8, 14)
	UiStyle.draw_text(self, Vector2(8, footer + 5.2), footer_left.to_upper(), 5, UiStyle.TEXT_FAINT, 200, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.REGULAR, 0.5)
	UiStyle.draw_text(self, Vector2(width - 116, footer + 5.2), footer_right.to_upper(), 5, UiStyle.TEXT_FAINT, 108, HORIZONTAL_ALIGNMENT_RIGHT, UiStyle.REGULAR, 0.5)
