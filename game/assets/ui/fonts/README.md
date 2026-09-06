# Interface typefaces

## DejaVu Serif (`DejaVuSerif.ttf`, `DejaVuSerif-Bold.ttf`)

The scalable face for the whole interface: dialogue, menus, names,
descriptions, objectives, battle information.

A serif was chosen deliberately. Crestbound is old-world dark fantasy,
and a humanist serif carries that register where a geometric sans reads
as a modern app. DejaVu Serif has a large, even lower case that stays
legible at 18px on a 1280x720 canvas, real bold weight for hierarchy, and
lining numerals with enough width difference between 1 and 7 to read a
damage number at a glance.

Licence: Bitstream Vera / public-domain DejaVu changes. Redistribution,
including inside a game, is permitted; see `LICENSE-DejaVu.txt`. The
files are unmodified, so the renaming clause does not apply.

## crestbound_font.fnt (in the parent directory)

The 8px bitmap face, authored by `tools/generate_font.py`. It is no
longer the interface font. It is retained as a deliberate accent for the
places where a pixel face is the *point* rather than a limitation:

- the boot title, which is the game's logotype
- small uppercase tags and unit labels inside the battle HUD

Everything else uses the serif. Because the bitmap face only survives
whole-number rescaling, any use of it must still be a multiple of 8;
`Typography` is the only place that decides, and
`test_pixel_accent_font_is_only_used_at_whole_multiples` enforces it.
