shader_type canvas_item;
render_mode unshaded, blend_add;
#include "res://scripts/overworld/painted_interior_light.gdshaderinc"

varying vec2 tile_pos;

void vertex() {
	tile_pos = VERTEX / 16.0;
}

void fragment() {
	COLOR = interior_light(tile_pos, TIME, true);
}
