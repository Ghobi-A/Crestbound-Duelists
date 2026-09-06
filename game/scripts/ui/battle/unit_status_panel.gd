extends Control
class_name UnitStatusPanel
## Responsive character card; all values are read from the authoritative unit.
##
## Every measurement derives from the card's own `size`, which the HUD
## computes from the canvas — the card does not know what resolution it
## is on. At 320x180 this was a 192x54 strip where the portrait was an
## 18x22 thumbnail of a 138x160 atlas crop; the card is now large enough
## to show that crop at better than half its authored size.

const ROW_SIZE := Vector2(268, 168)
const PAD := 10.0
## Portraits are cropped from the cast atlas at a consistent 138x160.
const PORTRAIT_ASPECT := 138.0 / 160.0

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
	PresentationLayout.texture_box(_portrait, _portrait_rect())
	add_child(_portrait)
	CharacterPresentation.apply_portrait(_portrait, unit.sprite_key())
	refresh()


func _notification(what: int) -> void:
	# The HUD sizes cards from the party count, and a container may settle
	# them again afterwards, so the portrait box follows the card rather
	# than being frozen at whatever size it had when bind() ran.
	if what == NOTIFICATION_RESIZED and _portrait != null:
		PresentationLayout.texture_box(_portrait, _portrait_rect())


## Vertical bands, measured from the bottom of the card upward.
func _tags_height() -> float:
	return Typography.CAPTION + PAD * 0.5


func _bars_height() -> float:
	return PAD * 2.6


func _body_top() -> float:
	return PAD + Typography.BODY + PAD * 0.5


func _portrait_rect() -> Rect2:
	var top := _body_top()
	var height := maxf(8.0, size.y - top - _bars_height() - _tags_height() - PAD)
	return Rect2(PAD, top, height * PORTRAIT_ASPECT, height)


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if unit == null:
		return
	UiStyle.draw_panel(self, Rect2(Vector2.ZERO, size), UiStyle.COMMAND if highlighted else UiStyle.NEUTRAL)
	var font := get_theme_default_font()
	var name := unit.display_name.trim_prefix("Warden ")
	var ink := PlaceholderPalette.TEXT_MAIN if unit.is_alive() else PlaceholderPalette.TEXT_DIM
	draw_string(font, Vector2(PAD, PAD + Typography.BODY), name,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2, Typography.BODY, ink)

	var portrait := _portrait_rect()
	var column_x := portrait.position.x + portrait.size.x + PAD
	var column_width := size.x - column_x - PAD
	draw_string(font, Vector2(column_x, portrait.position.y + Typography.HEADING), str(unit.hp),
		HORIZONTAL_ALIGNMENT_LEFT, column_width, Typography.HEADING, ink)
	draw_string(font, Vector2(column_x, portrait.position.y + Typography.HEADING + Typography.CAPTION + PAD * 0.4),
		"HP", HORIZONTAL_ALIGNMENT_LEFT, column_width, Typography.CAPTION, PlaceholderPalette.TEXT_DIM)

	var bar_width := size.x - PAD * 2
	var bar_height := PAD * 0.8
	var health_y := size.y - _tags_height() - _bars_height() + PAD * 0.2
	draw_rect(Rect2(PAD, health_y, bar_width, bar_height), Color("060a10"))
	var health_colour := Color("b95d60") if unit.hp_ratio() > 0.25 else Color("e09655")
	draw_rect(Rect2(PAD, health_y, bar_width * unit.hp_ratio(), bar_height), health_colour)
	if not unit.crest_record.is_empty():
		var resonance_y := health_y + bar_height + PAD * 0.3
		draw_rect(Rect2(PAD, resonance_y, bar_width, bar_height * 0.75), Color("060a10"))
		draw_rect(Rect2(PAD, resonance_y, bar_width * clampf(unit.resonance / 100.0, 0, 1), bar_height * 0.75),
			PlaceholderPalette.SPECTRAL_VIOLET)

	var tags: Array[String] = []
	if not unit.is_alive(): tags.append("DOWN")
	if unit.is_braced(): tags.append("BRACE")
	if unit.has_status("hexed"): tags.append("HEX")
	if unit.awakened: tags.append("AWAKE")
	if acted_marker: tags.append("READY")
	draw_string(font, Vector2(PAD, size.y - PAD * 0.5), " ".join(tags),
		HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2, Typography.CAPTION, PlaceholderPalette.TEXT_WARN)

	var details: Array[String] = [unit.display_name, "HP %d / %d" % [unit.hp, unit.max_hp], "Resonance %d" % unit.resonance]
	for status in unit.statuses: details.append(str(status.name))
	for modifier in unit.stat_mods: details.append("%s %+d" % [modifier.stat, modifier.amount])
	tooltip_text = "\n".join(details)
