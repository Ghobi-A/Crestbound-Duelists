class_name UiStyle
extends RefCounted
## The game-wide interface vocabulary: panels, frames, type, bars, selection.
##
## Every player-facing screen draws its chrome through here so the title,
## exploration HUD, dialogue, party setup, battle HUD and results read as
## one designed system. The look is "moonlit ledger": deep navy glass
## panels, gold hairline frames with small star-cross ornaments, and a
## letter-spaced monospace face (IBM Plex Mono, OFL) that stays crisp at
## every integer output scale because the layout is drawn at 2x-6x.
##
## Accent roles carry meaning rather than being decoration:
##   command — gold, the player's own agency (menus, the acting unit)
##   target  — violet, what an action affects (target info, round review)
##   neutral — slate, passive framing that should recede
##
## Geometry is in 320x180 logical pixels. Hairlines are fractions of a
## logical pixel so they land on ~2 physical pixels at 720p/1080p.

const COMMAND := "command"
const TARGET := "target"
const NEUTRAL := "neutral"

const HAIR := 0.5
const CORNER_LENGTH := 4

# Body copy size. Plex Mono is a vector face, so the old bitmap-font
# floor of 8px no longer applies; 5px is 10 physical px at 640x360 and
# 20-30px at 720p-1080p. Nothing smaller than MIN_FONT_SIZE is allowed.
const FONT_SIZE := 5
const MIN_FONT_SIZE := 5
const LABEL_SIZE := 5
const TITLE_SIZE := 7

const REGULAR := "Regular"
const MEDIUM := "Medium"
const SEMIBOLD := "SemiBold"
const FONT_PATH := "res://assets/ui/fonts/IBMPlexMono-%s.ttf"

# Surfaces: layered navy glass, lighter as it rises toward the player.
const SURFACE_OUTER := Color(0.027, 0.039, 0.067, 0.94)
const SURFACE_INNER := Color(0.047, 0.063, 0.102, 0.92)
const SURFACE_RAISED := Color(0.086, 0.106, 0.157, 0.95)
const SURFACE_LINE := Color("3b4459")
const GOLD := Color("c9a55a")
const GOLD_BRIGHT := Color("f0d38c")
const GOLD_DIM := Color("7d6a44")
const TEXT := Color("e9e4d6")
const TEXT_DIM := Color("9a9aa6")
const TEXT_FAINT := Color("646a7a")
const HP_FILL := Color("c33a3a")
const HP_FILL_LIGHT := Color("e2605a")
const HP_LOW := Color("e0943a")
const RS_FILL := Color("6f53c9")
const RS_FILL_LIGHT := Color("9c84ec")

static var _fonts: Dictionary = {}


static func accent_color(role: String) -> Color:
	match role:
		COMMAND:
			return GOLD
		TARGET:
			return PlaceholderPalette.SPECTRAL_VIOLET
		_:
			return Color("59627a")


static func font(weight := REGULAR, spacing := 0) -> Font:
	## Plex Mono in a weight. `spacing` (whole font px) is only for Labels;
	## drawn text uses fractional tracking in draw_text instead.
	var key := "%s/%d" % [weight, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var base: Font = load(FONT_PATH % weight)
	if base == null:
		base = ThemeDB.fallback_font
	var result: Font = base
	if spacing != 0:
		var variation := FontVariation.new()
		variation.base_font = base
		variation.spacing_glyph = spacing
		result = variation
	_fonts[key] = result
	return result


static func style_label(label: Label, size := FONT_SIZE, colour := TEXT, weight := REGULAR, spacing := 0) -> Label:
	label.add_theme_font_override("font", font(weight, spacing))
	label.add_theme_font_size_override("font_size", maxi(size, MIN_FONT_SIZE))
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func make_label(parent: Node, rect: Rect2, text := "", size := FONT_SIZE, colour := TEXT, weight := REGULAR, spacing := 0) -> Label:
	var label := Label.new()
	style_label(label, size, colour, weight, spacing)
	label.text = text
	parent.add_child(label)
	# Geometry after the theme overrides so the label keeps this box.
	label.position = rect.position
	label.size = rect.size
	label.clip_text = true
	return label


static func draw_text(canvas: CanvasItem, at: Vector2, text: String, size := FONT_SIZE, colour := TEXT,
		width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, weight := REGULAR, tracking := 0.0) -> void:
	## `at` is the baseline start, matching CanvasItem.draw_string. Tracking
	## (extra space between letters, in logical px) may be fractional; spaced
	## capitals are drawn glyph by glyph so the spacing lands exactly.
	var face := font(weight)
	var px := maxi(size, MIN_FONT_SIZE)
	if tracking <= 0.0:
		canvas.draw_string(face, at, text, align, width, px, colour)
		return
	var total := text_width(text, px, weight, tracking)
	var x := at.x
	if width > 0.0:
		if total > width:
			while text.length() > 1 and text_width(text, px, weight, tracking) > width:
				text = text.left(text.length() - 1)
			total = text_width(text, px, weight, tracking)
		if align == HORIZONTAL_ALIGNMENT_RIGHT:
			x += width - total
		elif align == HORIZONTAL_ALIGNMENT_CENTER:
			x += (width - total) / 2.0
	for character in text:
		canvas.draw_string(face, Vector2(x, at.y), character, HORIZONTAL_ALIGNMENT_LEFT, -1, px, colour)
		x += face.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking


static func text_width(text: String, size := FONT_SIZE, weight := REGULAR, tracking := 0.0) -> float:
	var base := font(weight).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(size, MIN_FONT_SIZE)).x
	return base + tracking * maxf(0.0, text.length() - 1)


static func draw_frame(canvas: CanvasItem, rect: Rect2, colour: Color, width := HAIR) -> void:
	## A hairline rectangle built from filled rects so it keeps its weight.
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), colour)
	canvas.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - width), Vector2(rect.size.x, width)), colour)
	canvas.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), colour)
	canvas.draw_rect(Rect2(rect.position + Vector2(rect.size.x - width, 0), Vector2(width, rect.size.y)), colour)


static func draw_panel(canvas: CanvasItem, rect: Rect2, role := NEUTRAL, ornate := true) -> void:
	## Navy glass with a gold (or role) hairline, a faint inner frame and,
	## when ornate, small bracket marks at each corner.
	var accent := accent_color(role)
	canvas.draw_rect(rect, SURFACE_OUTER)
	canvas.draw_rect(rect.grow(-1.5), SURFACE_INNER)
	# Soft top light: the panel reads as raised glass rather than a flat box.
	canvas.draw_rect(Rect2(rect.position + Vector2(1.5, 1.5), Vector2(rect.size.x - 3, 2)), Color(1, 1, 1, 0.025))
	draw_frame(canvas, rect, accent.darkened(0.35))
	draw_frame(canvas, rect.grow(-1.5), Color(accent, 0.16))
	if ornate:
		draw_corner_marks(canvas, rect, accent)


static func draw_corner_marks(canvas: CanvasItem, rect: Rect2, colour: Color) -> void:
	## Short brackets at each corner, drawn just inside the frame.
	var length := float(CORNER_LENGTH)
	var w := HAIR * 2.0
	for corner in [
		[rect.position, Vector2(1, 1)],
		[Vector2(rect.end.x, rect.position.y), Vector2(-1, 1)],
		[Vector2(rect.position.x, rect.end.y), Vector2(1, -1)],
		[rect.end, Vector2(-1, -1)],
	]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		canvas.draw_rect(Rect2(Vector2(minf(p.x, p.x + d.x * length), p.y if d.y > 0 else p.y - w), Vector2(length, w)), colour)
		canvas.draw_rect(Rect2(Vector2(p.x if d.x > 0 else p.x - w, minf(p.y, p.y + d.y * length)), Vector2(w, length)), colour)


static func draw_ornament(canvas: CanvasItem, centre: Vector2, radius := 2.5, colour := GOLD) -> void:
	## The star-cross flourish: a small diamond with fine spokes.
	var r := radius
	canvas.draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0, -r * 0.55), centre + Vector2(r * 0.55, 0),
		centre + Vector2(0, r * 0.55), centre + Vector2(-r * 0.55, 0)]), colour)
	canvas.draw_rect(Rect2(centre + Vector2(-r, -HAIR / 2), Vector2(r * 2, HAIR)), colour)
	canvas.draw_rect(Rect2(centre + Vector2(-HAIR / 2, -r), Vector2(HAIR, r * 2)), colour)


static func draw_divider(canvas: CanvasItem, from: Vector2, width: float, colour: Color, diamond := true) -> void:
	## A hairline rule, optionally pinched by a small diamond at centre.
	canvas.draw_rect(Rect2(from - Vector2(0, HAIR / 2), Vector2(width, HAIR)), Color(colour, 0.55))
	if diamond:
		draw_ornament(canvas, from + Vector2(width * 0.5, 0.0), 1.6, colour)


static func draw_header_underline(canvas: CanvasItem, rect: Rect2, role := COMMAND) -> void:
	## The accent rule beneath a screen or panel title.
	canvas.draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - HAIR), Vector2(rect.size.x, HAIR)), accent_color(role))


static func draw_selection_band(canvas: CanvasItem, rect: Rect2, role := COMMAND) -> void:
	## The selected list row: a warm raised fill inside a bright hairline
	## frame, with a solid pointer to its left so a still frame reads.
	var accent := accent_color(role)
	canvas.draw_rect(rect, Color(accent, 0.13))
	draw_frame(canvas, rect, accent.lightened(0.15))
	draw_pointer(canvas, Vector2(rect.position.x - 1.2, rect.position.y + rect.size.y / 2.0), accent.lightened(0.2))


static func draw_pointer(canvas: CanvasItem, tip: Vector2, colour := GOLD_BRIGHT, size := 2.4) -> void:
	## Right-pointing triangle whose tip sits at `tip`.
	canvas.draw_colored_polygon(PackedVector2Array([
		tip, tip + Vector2(-size, -size * 0.8), tip + Vector2(-size, size * 0.8)]), colour)


static func draw_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill: Color, fill_light: Color) -> void:
	## A gauge: dark track, lit two-tone fill and a hairline frame.
	canvas.draw_rect(rect, Color(0, 0, 0, 0.55))
	var filled := Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y))
	if filled.size.x > 0.0:
		canvas.draw_rect(filled, fill)
		canvas.draw_rect(Rect2(filled.position, Vector2(filled.size.x, rect.size.y * 0.4)), fill_light)
	draw_frame(canvas, rect, Color(1, 1, 1, 0.16), HAIR * 0.8)


static func draw_portrait_frame(canvas: CanvasItem, rect: Rect2, active := false) -> void:
	## Recessed well behind a portrait with a hairline frame; brighter for
	## the acting unit.
	canvas.draw_rect(rect, Color(0.02, 0.025, 0.04, 1.0))
	draw_frame(canvas, rect, (GOLD if active else Color("4a5266")))
	draw_frame(canvas, rect.grow(-1.0), Color(0, 0, 0, 0.5), HAIR)


static func draw_vignette_band(canvas: CanvasItem, rect: Rect2, top_alpha: float, bottom_alpha: float, steps := 12) -> void:
	## Vertical gradient of the outer surface colour, used to fade the
	## battlefield into the HUD and the title bar into the sky.
	var h := rect.size.y / float(steps)
	for i in steps:
		var t := (float(i) + 0.5) / float(steps)
		canvas.draw_rect(Rect2(rect.position + Vector2(0, i * h), Vector2(rect.size.x, h + 0.05)),
			Color(0.02, 0.03, 0.05, lerpf(top_alpha, bottom_alpha, t)))


static func draw_glyph(canvas: CanvasItem, glyph: String, centre: Vector2, radius := 2.4, colour := GOLD) -> void:
	## Line-art command glyphs drawn as vectors, so they stay crisp at HD
	## (the 7px icon atlas is kept for legacy callers).
	var r := radius
	var w := HAIR * 1.2
	match glyph:
		"slot_basic", "attack":
			# Sword: blade on the diagonal, crossguard, pommel.
			canvas.draw_line(centre + Vector2(-r * 0.8, r * 0.8), centre + Vector2(r, -r), colour, w)
			canvas.draw_line(centre + Vector2(-r * 0.75, r * 0.05), centre + Vector2(-r * 0.05, r * 0.75), colour, w)
			canvas.draw_circle(centre + Vector2(-r * 0.95, r * 0.95), w * 0.9, colour)
		"slot_signature", "skill":
			# Star-burst: eight spokes around a bright core.
			for i in 8:
				var a := TAU * i / 8.0
				var reach := r if i % 2 == 0 else r * 0.55
				canvas.draw_line(centre + Vector2.from_angle(a) * r * 0.25, centre + Vector2.from_angle(a) * reach, colour, w)
			canvas.draw_circle(centre, r * 0.2, colour)
		"slot_gambit":
			# Diamond with a notch: a risky, double-edged play.
			var d := PackedVector2Array([centre + Vector2(0, -r), centre + Vector2(r, 0), centre + Vector2(0, r), centre + Vector2(-r, 0), centre + Vector2(0, -r)])
			canvas.draw_polyline(d, colour, w)
			canvas.draw_line(centre + Vector2(-r * 0.45, 0), centre + Vector2(r * 0.45, 0), colour, w)
		"slot_brace", "brace":
			# Heater shield.
			var s := PackedVector2Array([
				centre + Vector2(-r * 0.85, -r * 0.85), centre + Vector2(r * 0.85, -r * 0.85),
				centre + Vector2(r * 0.8, r * 0.1), centre + Vector2(0, r), centre + Vector2(-r * 0.8, r * 0.1),
				centre + Vector2(-r * 0.85, -r * 0.85)])
			canvas.draw_polyline(s, colour, w)
			canvas.draw_line(centre + Vector2(0, -r * 0.6), centre + Vector2(0, r * 0.6), colour, w * 0.8)
		"objective":
			# Crossed blades.
			canvas.draw_line(centre + Vector2(-r, r), centre + Vector2(r, -r), colour, w)
			canvas.draw_line(centre + Vector2(-r, -r), centre + Vector2(r, r), colour, w)
		_:
			draw_ornament(canvas, centre, r, colour)


static func wrap(text: String, width: float, size := FONT_SIZE, weight := REGULAR) -> PackedStringArray:
	## Greedy word wrap against the real font metrics; honours "\n".
	var lines := PackedStringArray()
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			var candidate := word if line == "" else line + " " + word
			if line != "" and text_width(candidate, size, weight) > width:
				lines.append(line)
				line = word
			else:
				line = candidate
		lines.append(line)
	return lines
