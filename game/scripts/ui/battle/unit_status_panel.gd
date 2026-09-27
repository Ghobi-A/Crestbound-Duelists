extends Control
class_name UnitStatusPanel
## Party card: portrait well, name, HP and Resonance with values and gauges,
## and a status tag. All values are read from the authoritative unit.
const ROW_SIZE := Vector2(60, 31)
const PORTRAIT := Rect2(2.5, 2.5, 21, 22)
var unit: BattleUnit
var highlighted := false
var acted_marker := false
var _portrait: TextureRect


func _init() -> void:
	custom_minimum_size = ROW_SIZE
	size = ROW_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(unit_: BattleUnit) -> void:
	unit = unit_
	_portrait = TextureRect.new()
	PresentationLayout.texture_box(_portrait, PORTRAIT.grow(-0.75))
	add_child(_portrait)
	CharacterPresentation.apply_portrait(_portrait, unit.sprite_key())
	refresh()


func refresh() -> void:
	if _portrait != null:
		_portrait.modulate = Color.WHITE if unit.is_alive() else Color(0.45, 0.45, 0.5)
	queue_redraw()


func status_tag() -> String:
	## The single most important state, so it always fits under the portrait.
	if not unit.is_alive(): return "DOWN"
	if unit.awakened: return "AWAKE"
	if unit.has_status("hexed"): return "HEX"
	if unit.is_braced(): return "BRACE"
	if acted_marker: return "READY"
	return ""


func _draw() -> void:
	if unit == null:
		return
	UiStyle.draw_panel(self, Rect2(Vector2.ZERO, size), UiStyle.COMMAND if highlighted else UiStyle.NEUTRAL, highlighted)
	UiStyle.draw_portrait_frame(self, PORTRAIT, highlighted)
	var alive := unit.is_alive()
	var ink := UiStyle.TEXT if alive else UiStyle.TEXT_FAINT
	var x := PORTRAIT.end.x + 3.0
	var column := size.x - x - 3.0
	var name := unit.display_name.trim_prefix("Warden ").to_upper()
	# Spaced capitals when they fit; long names close the tracking instead
	# of being cut.
	var tracking := 0.6 if UiStyle.text_width(name, 5, UiStyle.MEDIUM, 0.6) <= column else 0.0
	UiStyle.draw_text(self, Vector2(x, 7.2), name, 5, UiStyle.GOLD_BRIGHT if highlighted else ink, column, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.MEDIUM, tracking)

	# HP: label left, value right, gauge beneath.
	UiStyle.draw_text(self, Vector2(x, 14.2), "HP", 5, UiStyle.TEXT_DIM, column)
	UiStyle.draw_text(self, Vector2(x, 14.2), "%d/%d" % [unit.hp, unit.max_hp], 5, ink, column, HORIZONTAL_ALIGNMENT_RIGHT)
	var low := unit.hp_ratio() <= 0.25
	UiStyle.draw_bar(self, Rect2(x, 15.6, column, 2.2), unit.hp_ratio(),
		UiStyle.HP_LOW if low else UiStyle.HP_FILL, UiStyle.HP_LOW.lightened(0.2) if low else UiStyle.HP_FILL_LIGHT)
	if not unit.crest_record.is_empty():
		UiStyle.draw_text(self, Vector2(x, 23.4), "RS", 5, UiStyle.TEXT_DIM, column)
		UiStyle.draw_text(self, Vector2(x, 23.4), "%d/100" % unit.resonance, 5, ink, column, HORIZONTAL_ALIGNMENT_RIGHT)
		UiStyle.draw_bar(self, Rect2(x, 24.8, column, 2.2), unit.resonance / 100.0, UiStyle.RS_FILL, UiStyle.RS_FILL_LIGHT)

	var tag := status_tag()
	if tag != "":
		var tag_colour := UiStyle.TEXT_FAINT if not alive else (UiStyle.RS_FILL_LIGHT if tag in ["AWAKE", "HEX"] else UiStyle.GOLD)
		UiStyle.draw_text(self, Vector2(PORTRAIT.position.x, 29.6), tag, 5, tag_colour, PORTRAIT.size.x, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.MEDIUM)
	var details: Array[String] = [unit.display_name, "HP %d / %d" % [unit.hp, unit.max_hp], "Resonance %d" % unit.resonance]
	for status in unit.statuses: details.append(str(status.name))
	for modifier in unit.stat_mods: details.append("%s %+d" % [modifier.stat, modifier.amount])
	tooltip_text = "\n".join(details)
