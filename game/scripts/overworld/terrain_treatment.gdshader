shader_type canvas_item;
render_mode unshaded, blend_mix;

// Large-scale ground variation, drawn over the tile layer.
//
// Greymere's terrain reads as flat not because the tiles are wrong but
// because a field of them repeats one 16px cell with no variation above
// that scale. Authored tiles cannot fix that on their own: the missing
// signal is lower-frequency than a tile. This adds it — broad damp
// patches, worn lighter ground, and a soft moonlight gradient — at a
// scale no tile set can carry, so it composes with whatever art is
// underneath rather than replacing it.
//
// Everything here is a function of world position, so it does not drift
// or shimmer when the camera moves, and it renders identically on every
// run for the screenshot harness.

uniform vec2 world_size = vec2(384.0, 224.0);
// Cool moonlight from the upper left, matching the rim direction the
// tile art is already drawn with.
uniform vec2 light_direction = vec2(-0.55, -0.83);
uniform float damp_strength : hint_range(0.0, 1.0) = 0.48;
uniform float wear_strength : hint_range(0.0, 1.0) = 0.30;
uniform float moonlight_strength : hint_range(0.0, 1.0) = 0.20;
uniform vec3 damp_tint = vec3(0.36, 0.45, 0.62);
uniform vec3 wear_tint = vec3(0.72, 0.66, 0.52);

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
	float b = dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

void fragment() {
	vec2 world = UV * world_size;

	// Damp ground: broad, soft, cool. Reads as low places holding water
	// after rain rather than as a texture.
	float damp = smoothstep(0.40, 0.80, fbm(world * 0.016));
	// Wear: tighter and warmer, where feet and carts have thinned the turf.
	float wear = smoothstep(0.46, 0.88, fbm(world * 0.048 + vec2(37.0, 11.0)));

	// A single broad gradient along the light direction keeps one side of
	// the town fractionally brighter, which gives the flat plan a sense
	// of a sky above it.
	float gradient = dot(normalize(light_direction), (UV - 0.5) * 2.0) * 0.5 + 0.5;

	vec3 tint = vec3(0.0);
	float alpha = 0.0;

	tint += damp_tint * damp * damp_strength;
	alpha += damp * damp_strength;

	tint += wear_tint * wear * wear_strength;
	alpha += wear * wear_strength;

	float moon = gradient * moonlight_strength;
	tint += vec3(0.70, 0.78, 1.0) * moon;
	alpha += moon;

	if (alpha <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(tint / alpha, clamp(alpha, 0.0, 1.0)) * COLOR.a;
	}
}
