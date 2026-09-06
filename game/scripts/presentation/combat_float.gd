class_name CombatFloatLayer
extends CanvasLayer
## One reusable, anchor-origin combat float system with per-unit stacking.

var _lanes: Dictionary = {}


func _ready() -> void:
	layer = 8


func show_float(unit: BattleUnit, origin: Vector2, kind: String, value := "") -> void:
	var lane := int(_lanes.get(unit, 0))
	_lanes[unit] = (lane + 1) % 3
	var label := Label.new()
	label.text = _text(kind, value)
	var role: Typography.Role = Typography.Role.NUMERIC if kind in ["damage", "heal"] else Typography.Role.HEADING
	var font_size := Typography.size(role)
	# Sized from the type it carries. The old 44x12 box was built around
	# 8px text and would clip every float on this canvas.
	var box := Vector2(font_size * 7.0, font_size * 1.5)
	# Lanes stack upward by a line each, so three simultaneous floats on
	# one unit stay legible instead of overprinting.
	label.position = origin + Vector2(-box.x * 0.5, -box.y - lane * box.y * 0.9)
	label.size = box
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Typography.apply(label, role, _color(kind))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.07, 0.9))
	label.add_theme_constant_override("outline_size", int(UiStyle.LINE * 2))
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - box.y * 0.7, 0.42)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.28).set_delay(0.16)
	tween.tween_callback(label.queue_free)


func _text(kind: String, value: String) -> String:
	match kind:
		"heal", "resonance": return "+" + value
		"blocked": return "BRACED"
		"hex": return "HEX"
		"miss": return "MISS"
		"defeat": return "DOWN"
		_: return value


func _color(kind: String) -> Color:
	match kind:
		"heal": return Color("78d88b")
		"resonance", "hex", "status": return PlaceholderPalette.SPECTRAL_VIOLET
		"blocked": return PlaceholderPalette.STEEL_GUARD
		"miss": return PlaceholderPalette.TEXT_DIM
		"defeat": return Color("b7aec8")
		_: return Color("fff1ce")
