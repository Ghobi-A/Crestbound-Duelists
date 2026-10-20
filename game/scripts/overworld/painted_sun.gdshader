shader_type canvas_item;
render_mode unshaded, blend_add;
#include "res://scripts/overworld/painted_light.gdshaderinc"

varying vec2 tile_pos;

void vertex() {
	tile_pos = VERTEX / 16.0;
}

void fragment() {
	COLOR = painted_light(tile_pos, TIME, true);
}
