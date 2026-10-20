extends Control
class_name TurnToken
## One unit on the turn-order rail: a portrait diamond rimmed in its side's
## colour, with a thin HP gauge for enemies. The BattleUnit remains the
## only HP/status source; the rail only chooses where tokens sit.

const SMALL := 13.0
const LEAD := 24.0

var unit: BattleUnit
var selected := false   # target cursor (violet)
var acting := false     # the Duelist being commanded (gold)
var lead := false       # drawn large at the head of the rail
var _portrait: TextureRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(value: BattleUnit) -> void:
	unit = value
	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	CharacterPresentation.apply_portrait(_portrait, unit.sprite_key())
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# The colour-key shader also clips the portrait to the diamond.
	var base: Material = _portrait.material if _portrait.material != null else CharacterPresentation.key_material({"colour_key": "alpha"})
	_portrait.material = base.duplicate()
	set_lead(false)


func set_lead(value: bool) -> void:
	lead = value
	var side := LEAD if lead else SMALL
	size = Vector2(side, side + (0.0 if unit.team == "player" else 4.0))
	if _portrait != null:
		_portrait.position = Vector2.ONE
		_portrait.size = Vector2(side - 2.0, side - 2.0)
		(_portrait.material as ShaderMaterial).set_shader_parameter("mask_size", _portrait.size)
	refresh()


func centre() -> Vector2:
	return position + Vector2(size.x / 2.0, size.x / 2.0)


func refresh() -> void:
	if _portrait != null:
		_portrait.modulate = Color.WHITE if unit.is_alive() else Color(0.35, 0.35, 0.4)
	queue_redraw()


func rim_colour() -> Color:
	if selected:
		return UiStyle.accent_color(UiStyle.TARGET)
	if acting:
		return UiStyle.GOLD_BRIGHT
	if lead and unit.team == "player":
		return Color("bfe0ff")
	return Color("5f8fd0") if unit.team == "player" else Color("c24a4a")


func _draw() -> void:
	if unit == null:
		return
	var side := size.x
	var c := Vector2(side, side) / 2.0
	var r := side / 2.0
	var diamond := func(radius: float) -> PackedVector2Array:
		return PackedVector2Array([c + Vector2(0, -radius), c + Vector2(radius, 0), c + Vector2(0, radius), c + Vector2(-radius, 0)])
	var rim := rim_colour()
	if lead or selected or acting:
		# Light bleeding off the rim: stacked outlines fading outward.
		var glow := Color("8fc2ff") if lead and unit.team == "player" and not selected else rim
		for i in 6:
			var grow := 0.6 + i * 0.55
			var outline: PackedVector2Array = diamond.call(r + grow)
			outline.append(outline[0])
			draw_polyline(outline, Color(glow, 0.5 * pow(1.0 - i / 6.0, 2.0)), 0.6)
	draw_colored_polygon(diamond.call(r), rim.darkened(0.25))
	draw_colored_polygon(diamond.call(r - 0.9), Color(0.03, 0.04, 0.07))
	if unit.team == "enemy" and unit.is_alive():
		var bar := Rect2(1.5, side + 1.0, side - 3.0, 1.6)
		UiStyle.draw_bar(self, bar, unit.hp_ratio(), UiStyle.HP_FILL, UiStyle.HP_FILL_LIGHT)
	if not unit.is_alive():
		draw_line(c + Vector2(-r * 0.45, -r * 0.45), c + Vector2(r * 0.45, r * 0.45), UiStyle.TEXT_FAINT, 0.8)
		draw_line(c + Vector2(r * 0.45, -r * 0.45), c + Vector2(-r * 0.45, r * 0.45), UiStyle.TEXT_FAINT, 0.8)
	# The portrait's diamond sits just inside this rim.
	draw_polyline(diamond.call(r - 0.5) + PackedVector2Array([c + Vector2(0, -(r - 0.5))]), rim, 0.7)
