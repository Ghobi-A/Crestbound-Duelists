shader_type canvas_item;
// Additive light on the town fountain: drifting glints across the basin and
// a bright ripple ring where the spout lands. Drawn over the static prop.
render_mode unshaded, blend_add;

uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float strength = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float inside = 1.0 - smoothstep(0.82, 1.0, length(p));
	float t = TIME;
	float glint = smoothstep(0.7, 0.9, texture(noise_tex, UV * vec2(2.2, 1.0) + vec2(t * 0.05, -t * 0.03)).b);
	float ring = smoothstep(0.08, 0.0, abs(length(p * vec2(1.0, 1.6) - vec2(0.0, -0.1)) - fract(t * 0.6) * 0.7)) * (1.0 - fract(t * 0.6));
	vec3 light = vec3(0.75, 0.9, 1.0) * (glint * 0.35 + ring * 0.25);
	COLOR = vec4(light * inside * strength, 1.0);
}
