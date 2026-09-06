class_name EnvironmentLayers
extends RefCounted
## The overworld's rendering bands, in one place.
##
## Greymere composites in a fixed order, and every layer below names the
## band it belongs to rather than inventing a z_index at the call site.
## That ordering is what produces depth: ground reads as flat because
## nothing sits above or below it, so the fix is layers, not brighter
## tiles.
##
## Everything that a character can walk in front of or behind shares
## ACTORS and is y-sorted within it — Godot y-sorts inside a z_index, so
## a prop that took its own z_index would stop sorting against the
## player. Bands other than ACTORS are deliberately unsorted.

## Terrain. The tile atlas paints here.
const GROUND := -40
## Large-scale ground variation over the tiles: damp patches, wear,
## moonlight falloff. Breaks up the flatness of a uniform grass field
## without needing a larger tile set.
const TERRAIN_TREATMENT := -35
## Painted-on wear: ruts, gravel verges, flowerbeds, tall grass.
const DECAL := -30
## Contact shadows, drawn under everything that stands up.
const SHADOW := -20
## Props, NPCs and the player. Y-sorted as one group.
const ACTORS := 0
## Canopy and eaves that a character passes behind.
const FOREGROUND := 40
## Additive light pools: lantern spill, warm windows.
const LIGHT := 60
## Mist and drifting motes.
const ATMOSPHERE := 80


static func make_layer(parent: Node2D, layer_name: String, band: int) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.z_index = band
	parent.add_child(layer)
	return layer
