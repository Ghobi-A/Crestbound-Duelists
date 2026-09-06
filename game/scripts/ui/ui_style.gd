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
	## A filled panel with a recessed bevel and a restrained accent border.
	var accent := accent_color(role)
	canvas.draw_rect(rect, PlaceholderPalette.MOON_SLATE)
	# A single lit top edge reads as a bevel without costing a second
	# colour ramp step.
	canvas.draw_rect(
		Rect2(rect.position + Vector2(LINE, LINE), Vector2(rect.size.x - LINE * 2, LINE)),
		PlaceholderPalette.MOON_INDIGO
	)
	canvas.draw_rect(rect, accent.darkened(0.4), false, LINE)
	if ornate:
		draw_corner_marks(canvas, rect, accent)


static func draw_corner_marks(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	## Short L-shaped marks at each corner — the one piece of ornament
	## the interface uses, kept to four small strokes per panel.
	var length := float(CORNER_LENGTH)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.position.x + rect.size.x - LINE
	var bottom := rect.position.y + rect.size.y - LINE
	for corner in [
		{"x": left, "y": top, "dx": 1.0, "dy": 1.0},
		{"x": right, "y": top, "dx": -1.0, "dy": 1.0},
		{"x": left, "y": bottom, "dx": 1.0, "dy": -1.0},
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
	## The filled band behind a highlighted list row, plus a leading
	## accent tick so the selected row is readable even in a still frame.
	canvas.draw_rect(rect, PlaceholderPalette.MOON_INDIGO)
	canvas.draw_rect(Rect2(rect.position, Vector2(LINE, rect.size.y)), accent_color(role))
