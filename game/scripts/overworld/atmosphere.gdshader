shader_type canvas_item;
render_mode unshaded, blend_add;

// Low ground mist over Greymere.
//
// An earlier version drew this as translucent rectangles, which put hard
// horizontal seams across the town — the edge of a mist band is exactly
// the thing that must not be visible. This is a single scrolling noise
// field with a soft vertical envelope instead, so it has no edges at all.
//
// Additive and very low amplitude: mist should suggest damp air between
// the camera and the far side of town, never veil the art.

uniform vec2 world_size = vec2(384.0, 224.0);
uniform float strength : hint_range(0.0, 0.5) = 0.085;
uniform vec3 mist_color = vec3(0.55, 0.66, 0.85);
uniform float drift_speed = 0.010;

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
	for (int i = 0; i < 3; i++) {
		total += value_noise(p) * amplitude;
		p *= 2.11;
		amplitude *= 0.5;
	}
	return total;
}

void fragment() {
	vec2 world = UV * world_size;
	// Two layers drifting at different rates so the pattern never
	// obviously repeats or reads as one moving object.
	float a = fbm(world * 0.017 + vec2(TIME * drift_speed * 6.0, TIME * drift_speed));
	float b = fbm(world * 0.031 + vec2(-TIME * drift_speed * 3.5, TIME * drift_speed * 0.5) + 19.0);
	float density = smoothstep(0.45, 0.95, a * 0.65 + b * 0.35);

	// Mist pools low and thins out toward the top of the map, which reads
	// as depth rather than as a flat wash.
	float envelope = smoothstep(0.10, 0.75, UV.y);
	COLOR = vec4(mist_color * density * envelope * strength, 1.0);
}
