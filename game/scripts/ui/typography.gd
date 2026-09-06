class_name Typography
extends RefCounted
## The game's type scale.
##
## crestbound_font.fnt is a bitmap face authored at 8px. Godot rescales
## bitmap glyphs to whatever size is requested, and only whole multiples
## of the native size survive that intact:
##
##   below 8px  — whole pixel rows are dropped, strokes vanish and
##                letters read as other letters (party setup once
##                rendered ACTIVE as NCTIVE at 7px).
##   non-integer multiples — stems land on uneven pixel counts, so the
##                same letter has different stroke weights across a word.
##
## So every size here is 8 * n. The 320x180 canvas could only afford
## n=1, which is why the whole interface was one undifferentiated size;
## at 1280x720 there is room for an actual hierarchy.
##
## These are logical sizes on the 1280x720 canvas. Integer window scaling
## keeps them exact multiples of the native face at any host size.

const NATIVE := 8

## Dense secondary data — status tags, unit HP captions, hint footers.
const CAPTION := 16   # 2x

## Default interface and dialogue text.
const BODY := 24      # 3x

## Panel titles and the names that head a card.
const HEADING := 32   # 4x

## Screen titles and full-width banners.
const DISPLAY := 48   # 6x


static func is_valid(size: int) -> bool:
	return size >= NATIVE and size % NATIVE == 0
