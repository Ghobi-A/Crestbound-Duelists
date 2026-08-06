class_name PresentationMetrics
## Single source of truth for canvas-scale presentation constants.
##
## Before this existed, the internal canvas size lived only as literals
## scattered across battle_hud.gd/boot_screen.gd/party_setup.gd/
## battle_controller.gd/screenshot_capture.gd, and the overworld tile
## size (`const TILE := 16`) was independently duplicated in
## greymere.gd, map_renderer.gd, npc.gd and player.gd — four copies that
## had to be kept in sync by hand. A resolution migration is exactly the
## kind of change that exposes duplicated constants as a bug source, so
## this file exists to remove that risk going forward: change the
## numbers here once, everything that reads them follows.
##
## This module is presentation-only. Gameplay values (encounter data,
## combat math, save schema) stay in their own files — this is strictly
## "how many pixels," never "how much damage."

const CANVAS_SIZE := Vector2i(640, 360)

## Overworld grid tile size, in pixels. Doubled from the original 16 as
## part of the 640x360 migration; every overworld script should read
## this rather than declare its own `const TILE`.
const TILE := 32

## Height of the battle background art, in pixels — the point where the
## HUD's opaque bottom panel begins. Must match the actual background
## PNG's height or a seam shows between the floor and the panel (the
## original 320x122 art had 122 for this exact reason). Doubled to 244
## alongside the canvas.
const BATTLE_BACKGROUND_HEIGHT := 244
