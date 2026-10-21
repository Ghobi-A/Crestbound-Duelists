// Shared by painted_interior_shade.gdshader (multiply) and
// painted_interior_glow.gdshader (add): candle pools and window light for
// a painted room, drawn above characters so they share its warm light.
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 lights[8];
uniform int light_count = 0;
uniform float windows[4];
uniform int window_count = 0;
uniform vec4 floor_rect = vec4(2.0, 3.0, 20.0, 12.0);
uniform vec2 shaft_dir = vec2(0.55, 1.0);
uniform float ambient = 0.8;

float pools(vec2 p, float time) {
	float total = 0.0;
	for (int i = 0; i < light_count; i++) {
		float flicker = 0.9 + 0.06 * sin(time * 2.7 + float(i) * 1.7) + 0.04 * sin(time * 6.3 + float(i));
		vec2 d = (p - lights[i]) * vec2(1.0, 1.35);
		total += exp(-dot(d, d) / 16.0) * flicker;
	}
	return total;
}

float shafts(vec2 p, float time) {
	float total = 0.0;
	vec2 dir = normalize(shaft_dir);
	vec2 across = vec2(dir.y, -dir.x);
	for (int i = 0; i < window_count; i++) {
		vec2 origin = vec2(windows[i], floor_rect.y);
		vec2 rel = p - origin;
		float along = dot(rel, dir);
		float side = abs(dot(rel, across));
		float beam = (1.0 - smoothstep(0.45, 1.1, side)) * smoothstep(-0.2, 0.6, along) * (1.0 - smoothstep(3.5, 8.0, along));
		// Dust drifting through the light.
		float motes = smoothstep(0.82, 0.95, texture(noise_tex, p / 1.2 + vec2(time * 0.02, -time * 0.035)).b);
		total += beam * (1.0 + motes * 1.5);
	}
	return total;
}

vec4 interior_light(vec2 p, float time, bool additive) {
	float pool = pools(p, time);
	float shaft = shafts(p, time);
	if (!additive) {
		float lit = clamp(ambient + pool * 0.45 + shaft * 0.35, 0.0, 1.0);
		return vec4(mix(vec3(0.55, 0.52, 0.62), vec3(1.0), lit), 1.0);
	}
	vec3 candle = vec3(1.0, 0.66, 0.32) * pool * 0.22;
	vec3 sun = vec3(1.0, 0.82, 0.5) * shaft * 0.26;
	return vec4(candle + sun, 1.0);
}
