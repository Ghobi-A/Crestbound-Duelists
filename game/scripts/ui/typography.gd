class_name Typography
extends RefCounted
## The interface's type system.
##
## Call sites ask for a *role*, never a font file and never a raw pixel
## size. That is what keeps one hierarchy across battle, dialogue, party
## setup, boot and onboarding instead of each screen picking its own
## sizes — and it is what makes the pixel-accent rule enforceable, since
## only this file decides which text is set in the bitmap face.
##
## Two faces, with a clear division of labour:
##
##   Serif (DejaVu Serif) — everything the player reads as language:
##     dialogue, names, descriptions, menu labels, objectives, numbers.
##     Old-world dark fantasy reads as a serif; a geometric sans would
##     read as a modern app.
##
##   Pixel (crestbound_font.fnt, 8px) — retained deliberately, not by
##     inertia, for the places where a pixel face is the point: the boot
##     logotype and the small uppercase tags in the battle HUD. It used
##     to be the universal interface font, which is what made a 720p
##     screen look like an upscaled 16-bit one.
##
## Sizes are free values for the serif. They stay whole multiples of 8
## for the pixel face, which only survives integral rescaling.

const SERIF_PATH := "res://assets/ui/fonts/DejaVuSerif.ttf"
const SERIF_BOLD_PATH := "res://assets/ui/fonts/DejaVuSerif-Bold.ttf"
const PIXEL_PATH := "res://assets/ui/crestbound_font.fnt"

## The bitmap face's authored size. Any pixel-accent size must be a whole
## multiple of this or glyph rows are dropped or unevenly doubled.
const PIXEL_NATIVE := 8

enum Role {
	## Screen titles and full-width banners.
	DISPLAY,
	## Panel titles and screen headers.
	TITLE,
	## Character names, menu entries, the things a player scans.
	HEADING,
	## Dialogue and any running prose.
	BODY,
	## Supporting copy: move descriptions, detail columns, hints.
	SECONDARY,
	## Dense annotation: units, footers, captions.
	CAPTION,
	## Large readouts — HP, damage. Bold for weight at a glance.
	NUMERIC,
	## Smaller readouts sitting beside a large one.
	NUMERIC_SMALL,
	## Pixel accent: the boot logotype.
	PIXEL_TITLE,
	## Pixel accent: small uppercase tags inside the HUD.
	PIXEL_TAG,
}

const _SIZES := {
	Role.DISPLAY: 44,
	Role.TITLE: 30,
	Role.HEADING: 24,
	Role.BODY: 20,
	Role.SECONDARY: 18,
	Role.CAPTION: 15,
	Role.NUMERIC: 40,
	Role.NUMERIC_SMALL: 17,
	Role.PIXEL_TITLE: 48,
	Role.PIXEL_TAG: 16,
}

const _BOLD_ROLES := [Role.DISPLAY, Role.TITLE, Role.HEADING, Role.NUMERIC]
const _PIXEL_ROLES := [Role.PIXEL_TITLE, Role.PIXEL_TAG]

static var _cache: Dictionary = {}


static func is_pixel(role: Role) -> bool:
	return _PIXEL_ROLES.has(role)


static func size(role: Role) -> int:
	return int(_SIZES.get(role, 20))


static func font(role: Role) -> Font:
	var path := PIXEL_PATH
	if not is_pixel(role):
		path = SERIF_BOLD_PATH if _BOLD_ROLES.has(role) else SERIF_PATH
	if not _cache.has(path):
		if not ResourceLoader.exists(path):
			push_error("Typography: missing face " + path)
			return null
		_cache[path] = load(path)
	return _cache[path] as Font


static func apply(label: Label, role: Role, color := Color.WHITE) -> Label:
	## Sets face, size and colour together. Splitting them is how a label
	## ends up with one screen's size and another's face.
	var face := font(role)
	if face != null:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size(role))
	label.add_theme_color_override("font_color", color)
	return label


static func line_height(role: Role) -> float:
	var face := font(role)
	if face == null:
		return float(size(role)) * 1.3
	return face.get_height(size(role))


static func measure(role: Role, text: String) -> Vector2:
	var face := font(role)
	if face == null:
		return Vector2.ZERO
	return face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size(role))


static func draw(canvas: CanvasItem, role: Role, baseline: Vector2, text: String,
		color: Color, width := -1.0, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	## For the custom-drawn panels. Same role vocabulary as `apply`, so a
	## card drawn in `_draw()` and a label built from nodes cannot drift
	## to different sizes for the same kind of text.
	var face := font(role)
	if face == null:
		return
	canvas.draw_string(face, baseline, text, alignment, width, size(role), color)
