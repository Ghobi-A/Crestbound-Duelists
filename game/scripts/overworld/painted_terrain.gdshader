shader_type canvas_item;
// Painted outdoor ground in one draw call. Material fields (built offline by
// tools/build_painted_terrain.py from the map rows) are thresholded through
// noise, so paths wind, corners round off and shorelines read as natural.
// Presentation only: collision still reads the map rows.

uniform sampler2D fields : filter_linear, repeat_disable;     // R path, G water, B forest, A tall grass
uniform sampler2D noise_tex : filter_linear, repeat_enable;   // tileable fBm: R broad, G medium, B fine
uniform sampler2D grass_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D path_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D water_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D tall_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_tiles = vec2(60.0, 35.0);
uniform float texture_tiles = 2.0;      // tiles covered by one material texture
uniform float edge_warp = 0.16;         // field units of noise added at edges
uniform float detail = 1.0;             // 0 on the Low preset: no water animation
uniform float time_scale = 1.0;
uniform vec3 forest_tint : source_color = vec3(0.10, 0.17, 0.09);

varying vec2 tile_pos;

void vertex() {
	tile_pos = VERTEX / 16.0;
}

vec3 sample_bombed(sampler2D tex, vec2 tiles, float variation) {
	// Two decorrelated lookups (rotated, scaled, offset) blended by broad
	// noise hide the material repeat without per-tile seams.
	vec2 uv = tiles / texture_tiles;
	const mat2 turn = mat2(vec2(0.799, 0.602), vec2(-0.602, 0.799));
	vec2 uv2 = turn * (uv * 0.83) + vec2(0.37, 0.71);
	float mix_t = smoothstep(0.35, 0.65, variation);
	return mix(texture(tex, uv).rgb, texture(tex, uv2).rgb, mix_t);
}

float edge(float field, float threshold, float warp, float softness) {
	return smoothstep(threshold - softness, threshold + softness, field + warp);
}

void fragment() {
	vec2 field_uv = tile_pos / map_tiles;
	vec4 f = texture(fields, field_uv);
	vec3 n_broad = texture(noise_tex, tile_pos / 23.0).rgb;
	// The path meanders: its field is read through a broad domain warp of
	// up to ~0.6 tile, so long straight edges bow and corners sweep.
	vec2 meander = (texture(noise_tex, tile_pos / 41.0).gb - 0.5) * 1.2;
	f.r = texture(fields, (tile_pos + meander) / map_tiles).r;
	// Shorelines wander too: a finer domain warp (up to ~0.35 tile) so pond
	// and creek edges never follow the tile grid in straight lines.
	vec2 shore = (texture(noise_tex, tile_pos / 9.0 + vec2(0.31, 0.77)).rg - 0.5) * 0.7;
	f.g = texture(fields, (tile_pos + shore) / map_tiles).g;
	vec3 n_fine = texture(noise_tex, tile_pos / 3.1).rgb;
	float warp = (n_fine.g - 0.5) * edge_warp * 2.0 + (n_broad.b - 0.5) * edge_warp;

	// Meadow base with a gentle broad tonal drift (sunlit / shaded patches).
	vec3 ground = sample_bombed(grass_tex, tile_pos, n_broad.r);
	// Sunlit meadow: lift and warm the grass toward the reference's yellow-green.
	ground = ground * vec3(1.22, 1.20, 0.98) + vec3(0.025, 0.03, 0.0);
	ground *= mix(0.88, 1.12, n_broad.g);

	// Tall encounter grass: denser, darker blades, still clearly grass.
	float tall = edge(f.a, 0.5, warp * 0.6, 0.08);
	vec3 tall_col = sample_bombed(tall_tex, tile_pos * 1.15, n_broad.g) * 0.92;
	ground = mix(ground, tall_col, tall);

	// Path (dirt or cobbles) with a darker verge where it meets grass.
	float path = edge(f.r, 0.5, warp, 0.035);
	float verge = edge(f.r, 0.42, warp, 0.05) * (1.0 - path);
	vec3 dirt = sample_bombed(path_tex, tile_pos, n_broad.b) * mix(0.92, 1.06, n_broad.r);
	ground = mix(ground, ground * vec3(0.66, 0.62, 0.48), verge * 0.7);
	ground = mix(ground, dirt, path);

	// Forest floor sinks into shade under the canopy.
	// Forest floor: tall undergrowth sinking into canopy shade.
	float forest = edge(f.b, 0.55, warp, 0.12);
	vec3 undergrowth = sample_bombed(tall_tex, tile_pos * 0.8, n_broad.r) * forest_tint * 4.0;
	ground = mix(ground, undergrowth, forest * 0.9);

	// Water sits inside its tiles (higher threshold), with a wet bank, a
	// depth gradient, drifting ripples and a thin shimmering foam line.
	float water = edge(f.g, 0.62, warp * 0.7, 0.02);
	float bank = edge(f.g, 0.44, warp * 0.7, 0.08) * (1.0 - water);
	ground = mix(ground, ground * vec3(0.55, 0.5, 0.42), bank * 0.6);
	float t = TIME * time_scale * detail;
	vec2 drift = vec2(t * 0.045, t * 0.02);
	vec3 surface = mix(texture(water_tex, tile_pos / 3.0 + drift).rgb,
		texture(water_tex, tile_pos / 2.3 - drift * 1.3 + 0.5).rgb, 0.5);
	// Brighten toward the sunlit teal of the reference, deeper toward the
	// middle, with a broad sky reflection drifting across the surface.
	float depth = smoothstep(0.62, 0.98, f.g);
	surface = surface * 1.45 + vec3(0.02, 0.08, 0.10);
	surface *= mix(vec3(1.08, 1.10, 1.04), vec3(0.72, 0.88, 1.0), depth);
	surface += vec3(0.30, 0.38, 0.42) * smoothstep(0.55, 0.85, texture(noise_tex, tile_pos / 9.0 + vec2(t * 0.01, 0.0)).r) * 0.35;
	float glint = smoothstep(0.78, 0.92, texture(noise_tex, tile_pos / 1.7 + vec2(t * 0.06, -t * 0.03)).b);
	surface += vec3(0.85, 0.92, 1.0) * glint * 0.25 * detail * (1.0 - depth * 0.5);
	float foam = (1.0 - smoothstep(0.0, 0.05, abs(f.g + warp * 0.7 - 0.64))) * (0.55 + 0.45 * sin(t * 1.7 + n_fine.r * 12.0));
	surface = mix(surface, vec3(0.86, 0.93, 0.95), foam * 0.35);
	ground = mix(ground, surface, water);

	COLOR = vec4(ground, 1.0);
}
