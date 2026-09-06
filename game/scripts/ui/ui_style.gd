class_name UiStyle
extends RefCounted
## The game-wide interface vocabulary: panel framing, trim and dividers.
##
## Every player-facing screen draws its chrome through here so the boot
## menu, party setup, dialogue, onboarding and battle HUD read as one
## designed system rather than four independently-styled screens.
##
## Accent roles carry meaning rather than being decoration:
##   command — gold, the player's own agency (menus, the acting unit)
##   target  — violet, what an action affects (target info, round review)
##   neutral — slate, passive framing that should recede
##
## Colour values live in PlaceholderPalette and match the Hollow Court
## background art exactly, so interface and battlefield share one palette.

const COMMAND := "command"
const TARGET := "target"
const NEUTRAL := "neutral"

# Trim scales with the canvas: a corner mark shorter than about 1% of
# the screen width stops reading as a flourish and starts reading as a
# broken border.
const CORNER_LENGTH := 12

# Chrome stroke weight. A 1px rule was a quarter of a scaled pixel-row at
# 320x180; on a 1280x720 canvas the same value renders as a hairline that
# reads as a rendering fault rather than a border, so strokes carry real
# weight while staying thinner in relative terms than they used to be.
const LINE := 2.0

# ── Surface tokens ───────────────────────────────────────────────────
# Panels are translucent, not opaque slabs. At 320x180 an opaque fill was
# the only way to keep text legible; at 720p the artwork behind a panel
# is worth seeing, and a surface that admits some of it is what separates
# a modern interface from a stack of window boxes. The gradient is subtle
# and runs light-to-dark downward, so a panel reads as lit from above by
# the same moon the artwork is.
const SURFACE_TOP := Color(0.086, 0.106, 0.153, 0.90)
const SURFACE_BOTTOM := Color(0.043, 0.055, 0.086, 0.94)
# A raised surface (a card sitting on a panel) is a step lighter, which
# is how depth is signalled rather than by drawing another border.
const SURFACE_RAISED_TOP := Color(0.125, 0.149, 0.204, 0.92)
const SURFACE_RAISED_BOTTOM := Color(0.075, 0.090, 0.129, 0.95)
# Hairline edge. Cool and low-contrast: the border defines the boundary,
# the accent says what the panel is for.
const EDGE := Color(0.35, 0.41, 0.52, 0.55)
# Panels cast a soft shadow so they lift off the artwork instead of
# being pasted onto it.
const SHADOW := Color(0.0, 0.0, 0.0, 0.34)
const SHADOW_DROP := 4.0

# Spacing scale. One rhythm across every screen; multiples of 4 so
# everything lands on whole pixels at any integer window scale.
const SPACE_XS := 4.0
const SPACE_S := 8.0
const SPACE_M := 16.0
const SPACE_L := 24.0
const SPACE_XL := 40.0

# The default interface size. Sizes live in Typography, which documents
# why only whole multiples of the 8px bitmap face are usable.
const FONT_SIZE := Typography.BODY


static func accent_color(role: String) -> Color:
	match role:
		COMMAND:
			return PlaceholderPalette.CREST_GOLD
		TARGET:
			return PlaceholderPalette.SPECTRAL_VIOLET
		_:
			# Light enough that it still reads as an edge after the
			# darkening draw_panel applies; MOON_INDIGO vanished against
			# the panel fill.
			return PlaceholderPalette.MOON_SLATE_LIGHT


static func draw_panel(canvas: CanvasItem, rect: Rect2, role := NEUTRAL, ornate := true) -> void:
	## The one surface every screen is built from.
	##
	## Reads as a pane of dark glass laid over the artwork: a soft cast
	## shadow, a translucent gradient body, a hairline edge, and the role
	## accent confined to a single lit rule along the top. Confining the
	## accent is deliberate — a full accent border on every panel was what
	## made the old interface read as a stack of framed boxes.
	draw_surface(canvas, rect, SURFACE_TOP, SURFACE_BOTTOM)
	var accent := accent_color(role)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, LINE)), accent)
	if ornate:
		draw_corner_marks(canvas, rect, accent)


static func draw_surface(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color,
		shadow := true) -> void:
	## Shadow, gradient body and hairline edge, without any accent. Used
	## directly by cards and scrims that carry no role of their own.
	if shadow:
		canvas.draw_rect(Rect2(rect.position + Vector2(0, SHADOW_DROP), rect.size), SHADOW)
	# draw_rect cannot gradient, but a quad with per-vertex colours can.
	canvas.draw_polygon(
		PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]),
		PackedColorArray([top, top, bottom, bottom])
	)
	canvas.draw_rect(rect, EDGE, false, 1.0)


static func draw_scrim(canvas: CanvasItem, rect: Rect2, strength := 0.72) -> void:
	## A vertical fade used behind text that sits over artwork. Lets the
	## art stay visible at the top of the band while guaranteeing contrast
	## where the text actually is, instead of dropping an opaque bar over
	## the picture.
	var steps := 10
	for i in steps:
		var t := float(i) / float(steps)
		var band := Rect2(
			rect.position + Vector2(0, rect.size.y * t),
			Vector2(rect.size.x, rect.size.y / float(steps) + 1.0)
		)
		canvas.draw_rect(band, Color(0.02, 0.03, 0.05, strength * t * t))


static func draw_corner_marks(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	## Short L-shaped marks at each corner — the one piece of ornament
	## the interface uses, kept to four small strokes per panel.
	var length := float(CORNER_LENGTH)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.position.x + rect.size.x - LINE
	var bottom := rect.position.y + rect.size.y - LINE
	# Two corners, not four. The mark is a flourish; on all four corners
	# it stops being ornament and becomes a frame.
	for corner in [
		{"x": left, "y": top, "dx": 1.0, "dy": 1.0},
		{"x": right, "y": bottom, "dx": -1.0, "dy": -1.0},
	]:
		var x: float = corner["x"]
		var y: float = corner["y"]
		var dx: float = corner["dx"]
		var dy: float = corner["dy"]
		var horizontal := Rect2(Vector2(minf(x, x + dx * length), y), Vector2(length, LINE))
		var vertical := Rect2(Vector2(x, minf(y, y + dy * length)), Vector2(LINE, length))
		canvas.draw_rect(horizontal, color)
		canvas.draw_rect(vertical, color)


static func draw_divider(canvas: CanvasItem, from: Vector2, width: float, color: Color, diamond := true) -> void:
	## A hairline rule, optionally pinched by a small diamond at centre —
	## used to separate a panel's header or its detail block.
	canvas.draw_rect(Rect2(from, Vector2(width, LINE)), color.darkened(0.25))
	if not diamond:
		return
	var centre := from + Vector2(width * 0.5, 0.0)
	canvas.draw_rect(Rect2(centre + Vector2(-LINE, -LINE), Vector2(LINE * 3, LINE)), color)
	canvas.draw_rect(Rect2(centre + Vector2(-LINE * 2, 0), Vector2(LINE * 5, LINE)), color)
	canvas.draw_rect(Rect2(centre + Vector2(-LINE, LINE), Vector2(LINE * 3, LINE)), color)


static func draw_header_underline(canvas: CanvasItem, rect: Rect2, role := COMMAND) -> void:
	## The accent rule beneath a screen or panel title.
	var accent := accent_color(role)
	canvas.draw_rect(
		Rect2(Vector2(rect.position.x, rect.position.y + rect.size.y - LINE), Vector2(rect.size.x, LINE)),
		accent
	)


static func draw_selection_band(canvas: CanvasItem, rect: Rect2, role := COMMAND) -> void:
	## The band behind a highlighted list row.
	##
	## A wash that fades out to the right rather than a flat block: the
	## selection should feel like light falling on the row from the accent
	## tick, not like a second panel laid on top of the first.
	var accent := accent_color(role)
	var tint := accent
	tint.a = 0.22
	var fade := accent
	fade.a = 0.0
	canvas.draw_polygon(
		PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]),
		PackedColorArray([tint, fade, fade, tint])
	)
	canvas.draw_rect(Rect2(rect.position, Vector2(LINE * 1.5, rect.size.y)), accent)
