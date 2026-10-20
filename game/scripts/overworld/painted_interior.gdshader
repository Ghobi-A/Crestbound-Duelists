shader_type canvas_item;
// Painted interior room in one draw: warm plank floor with soft contact
// shadow along the walls, a stone-and-timber back wall face, dark timber
// wall caps around the room and a stone threshold at the door. Rooms are
// rectangles, so everything derives from the floor and door rects.

uniform sampler2D floor_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec4 floor_rect = vec4(2.0, 3.0, 20.0, 12.0);   // x0, y0, x1, y1 in tiles (end exclusive)
uniform vec4 door_rect = vec4(10.0, 11.0, 12.0, 12.0);
uniform float wall_rows = 2.0;

varying vec2 tile_pos;

void vertex() {
	tile_pos = VERTEX / 16.0;
}

bool inside(vec2 p, vec4 r) {
	return p.x >= r.x && p.x < r.z && p.y >= r.y && p.y < r.w;
}

void fragment() {
	vec2 p = tile_pos;
	vec3 broad = texture(noise_tex, p / 17.0).rgb;
	vec3 col = vec3(0.0);
	vec4 room = vec4(floor_rect.x - 1.0, floor_rect.y - wall_rows, floor_rect.z + 1.0, floor_rect.w + 1.0);
	if (inside(p, floor_rect)) {
		// Planks run horizontally: offset-only second lookup keeps their
		// direction while broad noise hides the repeat.
		// Long boards: the texture spans 4 tiles across and 2 down.
		vec2 board = p / vec2(4.0, 2.0);
		vec3 a = texture(floor_tex, board).rgb;
		vec3 b = texture(floor_tex, board + vec2(0.5, 0.37)).rgb;
		col = mix(a, b, smoothstep(0.4, 0.6, broad.r)) * mix(0.9, 1.1, broad.g) * vec3(1.18, 1.1, 0.98);
		// Contact shadow: deepest under the back wall, soft along the sides.
		float back = smoothstep(0.0, 1.3, p.y - floor_rect.y);
		float sides = smoothstep(0.0, 0.7, min(p.x - floor_rect.x, floor_rect.z - p.x));
		float front = smoothstep(0.0, 0.5, floor_rect.w - p.y);
		col *= mix(0.42, 1.0, back) * mix(0.62, 1.0, sides) * mix(0.75, 1.0, front);
		if (inside(p, door_rect)) {
			vec3 stone = texture(stone_tex, p / 2.0).rgb * 1.1;
			col = mix(col, stone, 0.92);
		}
	} else if (p.y >= room.y && p.y < floor_rect.y && p.x >= floor_rect.x && p.x < floor_rect.z) {
		// Back wall face: texture spans 4 tiles across and the full height,
		// darkening toward the ceiling, with a timber skirting at its foot.
		float v = (p.y - room.y) / wall_rows;
		col = texture(wall_tex, vec2(p.x / 4.0, v)).rgb;
		col *= mix(0.78, 1.12, smoothstep(0.0, 0.7, v));
		float skirting = smoothstep(0.9, 0.93, v);
		col = mix(col, texture(floor_tex, p / 2.0).rgb * 0.45, skirting);
	} else if (inside(p, room)) {
		// Timber wall caps seen from above, with a lit inner edge.
		col = texture(floor_tex, p.yx / 2.0).rgb * 0.38;
		float edge = min(min(abs(p.x - floor_rect.x), abs(p.x - floor_rect.z)), abs(p.y - floor_rect.w));
		col += vec3(0.16, 0.11, 0.06) * (1.0 - smoothstep(0.0, 0.15, edge));
	}
	COLOR = vec4(col, 1.0);
}
