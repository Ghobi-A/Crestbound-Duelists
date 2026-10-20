// Shared by painted_shade.gdshader (multiply) and painted_sun.gdshader (add):
// world-space sun lighting over a painted map, drawn above characters so
// they share the scene's light. Subtle enough that sprites stay readable.
uniform sampler2D fields : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 map_tiles = vec2(60.0, 35.0);
uniform vec2 sun_dir = vec2(0.82, 0.57);    // light travels down-right
uniform vec3 sun_colour : source_color = vec3(1.0, 0.82, 0.52);
uniform vec3 shade_colour : source_color = vec3(0.62, 0.70, 0.86);
uniform float strength = 1.0;

vec4 painted_light(vec2 tile_pos, float time, bool additive) {
	vec4 f = texture(fields, tile_pos / map_tiles);
	// Wider forest proximity than the terrain uses: shade spills onto grass.
	float near_forest = smoothstep(0.04, 0.6, f.b);
	vec2 wind = vec2(time * 0.05, time * 0.018);
	float leaves = texture(noise_tex, tile_pos / 2.6 + wind).g * 0.6 + texture(noise_tex, tile_pos / 1.3 - wind * 1.4).b * 0.4;
	float dapple = smoothstep(0.48, 0.62, leaves);
	if (!additive) {
		float shade = near_forest * (0.55 + 0.45 * (1.0 - dapple));
		float water = smoothstep(0.6, 0.9, f.g);
		vec3 mul = mix(vec3(1.0), shade_colour, clamp(shade * 0.6 * strength, 0.0, 1.0));
		mul = mix(mul, vec3(0.94, 0.97, 1.0), water * 0.5);
		return vec4(mul, 1.0);
	} else {
		// Shafts: soft bands across the sun direction, broken by broad noise
		// and drifting slowly, brightest in open ground.
		vec2 across = vec2(-sun_dir.y, sun_dir.x);
		float band = dot(tile_pos, across) / 7.5 + texture(noise_tex, tile_pos / 31.0).r * 1.7;
		float shafts = pow(max(0.0, sin(band * 3.14159 + time * 0.07)), 6.0);
		shafts *= smoothstep(0.25, 0.7, texture(noise_tex, tile_pos / 19.0 + vec2(time * 0.004, 0.0)).g);
		float open = 1.0 - near_forest * 0.6;
		float highlight = dapple * near_forest * 0.5;
		float light = (shafts * 0.30 * open + highlight * 0.16 + open * 0.035) * strength;
		return vec4(sun_colour * light, 1.0);
	}
}
