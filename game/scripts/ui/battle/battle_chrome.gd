extends Control
class_name BattleChrome
## Static framing for the battle screen, drawn under the interactive HUD:
## the title bar (encounter title, objective, round), the fade from the
## battlefield into the command deck, the deck's glass and the footer.
## Presentation only; every string is supplied by BattleHud.

var title := ""
var round_text := ""
var objective := ""
var footer_left := ""
var footer_right := ""


func _init() -> void:
	size = PresentationLayout.CANVAS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var width := PresentationLayout.CANVAS.x
	var bar := float(PresentationLayout.TOP_BAR_HEIGHT)
	var field := float(PresentationLayout.BATTLE_HEIGHT)
	var footer := float(PresentationLayout.FOOTER_TOP)

	# Title bar: dark glass fading into the sky, gold hairline beneath.
	UiStyle.draw_vignette_band(self, Rect2(0, 0, width, bar + 5), 0.92, 0.0, 10)
	draw_rect(Rect2(0, 0, width, bar), Color(0.02, 0.03, 0.05, 0.55))
	draw_rect(Rect2(0, bar - UiStyle.HAIR, width, UiStyle.HAIR), Color(UiStyle.GOLD, 0.45))
	var heading := title.to_upper()
	var heading_width := UiStyle.text_width(heading, 6, UiStyle.MEDIUM, 1.4)
	UiStyle.draw_text(self, Vector2((width - heading_width) / 2.0, 7.8), heading, 6, UiStyle.TEXT, -1, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.MEDIUM, 1.4)
	UiStyle.draw_ornament(self, Vector2((width - heading_width) / 2.0 - 7, bar - 0.2), 2.6)
	UiStyle.draw_ornament(self, Vector2((width + heading_width) / 2.0 + 5, bar - 0.2), 2.6)
	if objective != "":
		UiStyle.draw_glyph(self, "objective", Vector2(8, 5.5), 2.0, UiStyle.GOLD)
		UiStyle.draw_text(self, Vector2(13, 7.5), objective.to_upper(), 5, UiStyle.TEXT_DIM, 90, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.REGULAR, 0.5)
	UiStyle.draw_text(self, Vector2(width - 96, 7.5), round_text.to_upper(), 5, UiStyle.TEXT_DIM, 90, HORIZONTAL_ALIGNMENT_RIGHT, UiStyle.REGULAR, 0.5)

	# The floor sinks into the deck instead of meeting it at a hard seam.
	UiStyle.draw_vignette_band(self, Rect2(0, field - 14, width, 14), 0.0, 0.85, 12)

	# Command deck and footer.
	draw_rect(Rect2(0, field, width, 180 - field), Color(0.025, 0.035, 0.06, 0.97))
	draw_rect(Rect2(0, field, width, UiStyle.HAIR), Color(UiStyle.GOLD, 0.6))
	UiStyle.draw_ornament(self, Vector2(width / 2.0, field), 2.4)
	UiStyle.draw_corner_marks(self, Rect2(2, field + 1.5, width - 4, footer - field - 2), UiStyle.GOLD_DIM)
	draw_rect(Rect2(10, footer + 0.5, width - 20, UiStyle.HAIR), Color(UiStyle.GOLD, 0.22))
	UiStyle.draw_ornament(self, Vector2(6, footer + 4.5), 1.8, UiStyle.GOLD_DIM)
	UiStyle.draw_ornament(self, Vector2(width - 6, footer + 4.5), 1.8, UiStyle.GOLD_DIM)
	UiStyle.draw_text(self, Vector2(11, footer + 6.4), footer_left.to_upper(), 5, UiStyle.TEXT_FAINT, 196, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.REGULAR, 0.5)
	UiStyle.draw_text(self, Vector2(width - 119, footer + 6.4), footer_right.to_upper(), 5, UiStyle.TEXT_FAINT, 108, HORIZONTAL_ALIGNMENT_RIGHT, UiStyle.REGULAR, 0.5)
