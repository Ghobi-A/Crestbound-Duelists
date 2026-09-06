extends Control
class_name UnitStatusPanel
## Responsive character card; all values are read from the authoritative unit.
##
## Composition, rather than a bordered box with fields in it. The portrait
## sits in a cut-out that breaks the card's top edge, so the character
## reads as the subject and the panel as something behind them — the same
## reason a magazine cover crops a face over the masthead. Name, HP and
## status then form one clear vertical hierarchy beside it instead of
## three equally-weighted rows.
##
## Every measurement derives from the card's own `size`, which the HUD
## computes from the canvas, so the card does not know what resolution it
## is on.

const ROW_SIZE := Vector2(268, 192)
const PAD := 12.0
## Portraits are cropped from the cast atlas at a consistent 138x160.
const PORTRAIT_ASPECT := 138.0 / 160.0
## How far the portrait rises above the card's top edge.
const PORTRAIT_OVERHANG := 26.0
const BAR_HEIGHT := 7.0

var unit: BattleUnit
var highlighted := false
var acted_marker := false
var _portrait: TextureRect


func _init() -> void:
	custom_minimum_size = ROW_SIZE
	size = ROW_SIZE
	# The portrait deliberately overflows the top edge, so this card must
	# not clip its own children.
	clip_contents = false


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


func _portrait_rect() -> Rect2:
	## Driven by the card's width, not its height. Sizing from height made
	## the portrait 141px wide on a 269px card, which left too little room
	## beside it and clipped "Almyra" to "Almyr".
	var width := size.x * 0.34
	return Rect2(PAD, -PORTRAIT_OVERHANG, width, width / PORTRAIT_ASPECT + PORTRAIT_OVERHANG)


func _text_left() -> float:
	return _portrait_rect().end.x + PAD


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if unit == null:
		return
	var card := Rect2(Vector2.ZERO, size)
	if highlighted:
		# The acting unit is lifted, not outlined: a lighter surface and a
		# full gold top rule, so the eye finds it without another border.
		UiStyle.draw_surface(self, card, UiStyle.SURFACE_RAISED_TOP, UiStyle.SURFACE_RAISED_BOTTOM)
		draw_rect(Rect2(card.position, Vector2(card.size.x, UiStyle.LINE)),
			PlaceholderPalette.CREST_GOLD)
	else:
		UiStyle.draw_surface(self, card, UiStyle.SURFACE_TOP, UiStyle.SURFACE_BOTTOM)

	var font := get_theme_default_font()
	var ink := PlaceholderPalette.TEXT_MAIN if unit.is_alive() else PlaceholderPalette.TEXT_DIM
	var portrait := _portrait_rect()
	var left := portrait.end.x + PAD
	var column := size.x - left - PAD

	# HP is the number read most often mid-battle, so it takes the largest
	# type and sits beside the portrait where the eye already is.
	var hp_baseline := PAD + Typography.DISPLAY
	draw_string(font, Vector2(left, hp_baseline), str(unit.hp),
		HORIZONTAL_ALIGNMENT_LEFT, column, Typography.DISPLAY, ink)
	draw_string(font, Vector2(left, hp_baseline + Typography.CAPTION + PAD * 0.3),
		"/ %d  HP" % unit.max_hp, HORIZONTAL_ALIGNMENT_LEFT, column, Typography.CAPTION,
		PlaceholderPalette.TEXT_DIM)

	# The name spans the whole card beneath the portrait rather than
	# sharing a line with it. Beside a portrait there is only ~140px, and
	# "Liora Sen" needs 171 at body size — no portrait small enough to fix
	# that would still read as a portrait.
	var bars_y := size.y - PAD - BAR_HEIGHT * 2 - UiStyle.SPACE_XS
	var name_baseline := bars_y - UiStyle.SPACE_M
	var name := unit.display_name.trim_prefix("Warden ")
	draw_string(font, Vector2(PAD, name_baseline), name,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2, Typography.BODY, ink)

	# Bars run the card's full width, tying the two columns together.
	_draw_bar(Rect2(PAD, bars_y, size.x - PAD * 2, BAR_HEIGHT), unit.hp_ratio(),
		Color("b95d60") if unit.hp_ratio() > 0.25 else Color("e09655"))
	if not unit.crest_record.is_empty():
		_draw_bar(Rect2(PAD, bars_y + BAR_HEIGHT + UiStyle.SPACE_XS, size.x - PAD * 2, BAR_HEIGHT),
			clampf(unit.resonance / 100.0, 0, 1), PlaceholderPalette.SPECTRAL_VIOLET)

	# Pips sit on the name's baseline, right-aligned, so a unit with no
	# statuses simply leaves that corner empty.
	_draw_status_pips(Vector2(size.x - PAD, name_baseline - Typography.BODY * 0.35))

	var details: Array[String] = [unit.display_name, "HP %d / %d" % [unit.hp, unit.max_hp], "Resonance %d" % unit.resonance]
	for status in unit.statuses: details.append(str(status.name))
	for modifier in unit.stat_mods: details.append("%s %+d" % [modifier.stat, modifier.amount])
	tooltip_text = "\n".join(details)


func _draw_bar(rect: Rect2, ratio: float, fill: Color) -> void:
	draw_rect(rect, Color(0.02, 0.03, 0.05, 0.85))
	if ratio > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill)
	draw_rect(rect, UiStyle.EDGE, false, 1.0)


func _draw_status_pips(at: Vector2) -> void:
	## Status as coloured pips rather than a row of words. At a glance the
	## player needs to know how many effects are on a unit and roughly
	## what kind; the exact names live in the tooltip and the round plan.
	var pips: Array[Color] = []
	if not unit.is_alive():
		pips.append(PlaceholderPalette.TEXT_DANGER)
	if unit.is_braced():
		pips.append(PlaceholderPalette.STEEL_GUARD)
	if unit.has_status("hexed"):
		pips.append(PlaceholderPalette.SPECTRAL_VIOLET)
	if unit.awakened:
		pips.append(PlaceholderPalette.CREST_GOLD_BRIGHT)
	if acted_marker:
		pips.append(PlaceholderPalette.MOON_SLATE_LIGHT)
	var radius := 4.0
	var pitch := radius * 2 + UiStyle.SPACE_XS
	for i in pips.size():
		# Laid out leftward from the anchor so the row stays right-aligned.
		var centre := at + Vector2(-radius - float(pips.size() - 1 - i) * pitch, 0)
		draw_circle(centre, radius, pips[i])
		draw_circle(centre, radius * 0.45, Color(0.02, 0.03, 0.05, 0.55))
