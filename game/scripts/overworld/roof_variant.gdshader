shader_type canvas_item;
// Re-roofs a reused building: only the painted blue roof slate (and the
// matching blue trim) is rotated to another hue, so windows, timber, stone
// and foliage keep their authored colours. Presentation only.
uniform float hue_shift = 0.0;        // turns, 0..1
uniform float saturation_scale = 1.0;
uniform float value_scale = 1.0;
// Vertex colour carries modulate; the fragment replaces only the texture sample.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(texel.rgb);
	// Roof slate sits around hue 0.60-0.70 with visible saturation.
	float roof = smoothstep(0.52, 0.58, hsv.x) * (1.0 - smoothstep(0.72, 0.78, hsv.x)) * smoothstep(0.12, 0.25, hsv.y);
	vec3 shifted = hsv2rgb(vec3(fract(hsv.x + hue_shift), clamp(hsv.y * saturation_scale, 0.0, 1.0), hsv.z * value_scale));
	COLOR = vec4(mix(texel.rgb, shifted, roof), texel.a) * tint;
}
