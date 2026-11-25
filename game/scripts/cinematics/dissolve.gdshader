shader_type canvas_item;
// Breaks a sprite apart into light: texels vanish where a value-noise field
// falls under `progress`, rising from the bottom first, and the edge that is
// about to go glows in `glow`. Used by CinematicPlayer "dissolve" elements.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow : source_color = vec4(0.81, 0.91, 1.0, 1.0);
uniform float edge = 0.08;
uniform float grain = 18.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float n = noise(UV * grain) * 0.6 + noise(UV * grain * 2.7) * 0.4;
	// Bias by height so the form crumbles upward into the sky.
	float field = n * 0.75 + (1.0 - UV.y) * 0.25;
	float cut = progress * 1.15;
	if (field < cut) {
		discard;
	}
	float rim = 1.0 - smoothstep(cut, cut + edge, field);
	vec3 colour = mix(base.rgb, glow.rgb, rim * step(0.001, progress));
	COLOR = vec4(colour + glow.rgb * rim * 0.6 * step(0.001, progress), base.a);
}
