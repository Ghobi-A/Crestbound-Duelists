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
var prompts: Array = [["Z", "Confirm"], ["X", "Back"]]
var rail_from := 6.0
var rail_mid := 120.0
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

	# Turn-order rail: a cool line through the allies, a warm one through
	# the enemies, each with a faint bloom, meeting at the round marker.
	var rail_y := 3.0 + 6.5 + TurnToken.SMALL / 2.0
	var ally := Color("6fa8ec")
	var foe := Color("d0574f")
	for segment in [[rail_from, rail_mid - 4.0, ally], [rail_mid + 4.0, rail_to, foe]]:
		var a: float = segment[0]
		var b: float = segment[1]
		var tint: Color = segment[2]
		if b <= a:
			continue
		draw_rect(Rect2(a, rail_y - 1.6, b - a, 3.2), Color(tint, 0.07))
		draw_rect(Rect2(a, rail_y - 0.8, b - a, 1.6), Color(tint, 0.14))
		draw_rect(Rect2(a, rail_y - 0.3, b - a, 0.6), Color(tint.lightened(0.35), 0.85))
		var pip := a + 10.0
		while pip < b - 4.0:
			_draw_pip(Vector2(pip, rail_y), tint)
			pip += 14.0
	for i in 5:
		draw_circle(Vector2(rail_mid, rail_y), 5.0 - i, Color(UiStyle.GOLD_BRIGHT, 0.05 + i * 0.03))
	UiStyle.draw_ornament(self, Vector2(rail_mid, rail_y), 4.0, UiStyle.GOLD_BRIGHT)
	if objective != "":
		UiStyle.draw_glyph(self, "objective", Vector2(10, 35.0), 1.8, UiStyle.GOLD)
		UiStyle.draw_text(self, Vector2(14.5, 37.2), objective.to_upper(), 5, UiStyle.TEXT_DIM, 120, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.DISPLAY, 0.6)

	# Encounter title box.
	UiStyle.draw_panel(self, TITLE_BOX, UiStyle.NEUTRAL, false)
	UiStyle.draw_glow_frame(self, TITLE_BOX, Color("c8d4ff"), 2.0, 0.12)
	var heading := title.to_upper()
	# Long encounter names step down in tracking, then size, instead of being cut.
	var size := 6
	var tracking := 1.6
	for option in [[6, 1.6], [6, 0.6], [5, 0.6], [5, 0.0]]:
		size = option[0]
		tracking = option[1]
		if UiStyle.text_width(heading, size, UiStyle.DISPLAY, tracking) <= TITLE_BOX.size.x - 8:
			break
	UiStyle.draw_text(self, TITLE_BOX.position + Vector2(5, 8.2), heading, size, UiStyle.TEXT, TITLE_BOX.size.x - 8, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.DISPLAY, tracking)
	UiStyle.draw_text(self, TITLE_BOX.position + Vector2(5, 15.8), round_text.to_upper(), 5, UiStyle.TEXT_DIM, TITLE_BOX.size.x - 8, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.DISPLAY, 0.9)

	# The floor darkens under the party cards instead of meeting a hard deck.
	UiStyle.draw_vignette_band(self, Rect2(0, deck - 14, width, 180 - deck + 14), 0.0, 0.8, 14)
	# Button prompts as key caps, then the sub-phase and battlefield effect.
	var x := 8.0
	for prompt in prompts:
		x += UiStyle.draw_key_cap(self, Vector2(x, footer + 3.4), prompt[0], prompt[1], UiStyle.TEXT_DIM)
	if footer_left != "":
		UiStyle.draw_text(self, Vector2(x + 2.0, footer + 5.4), footer_left.to_upper(), 5, UiStyle.GOLD_DIM, 90, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.DISPLAY, 0.7)
	UiStyle.draw_text(self, Vector2(width - 156, footer + 5.4), footer_right.to_upper(), 5, UiStyle.TEXT_FAINT, 148, HORIZONTAL_ALIGNMENT_RIGHT, UiStyle.DISPLAY)


func _draw_pip(at: Vector2, tint: Color) -> void:
	var r := 1.6
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), Color(0.04, 0.05, 0.09))
	var outline := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0), at + Vector2(0, -r)])
	draw_polyline(outline, tint.lightened(0.4), 0.5)
