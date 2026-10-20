shader_type canvas_item;
// Screen-space finishing pass for painted outdoor scenes, drawn under the
// HUD: a warm/cool colour grade, a soft vignette and, on the High preset,
// a tilt-shift blur toward the top and bottom of the frame and a gentle
// bloom on bright highlights. Taps are few and bounded for web builds.

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform bool blur_enabled = true;
uniform float tilt_start = 0.58;    // |y| (0 centre, 1 edge) where blur begins
uniform float tilt_radius = 2.4;    // logical px at the frame edge
uniform float bloom_strength = 0.22;
uniform float bloom_threshold = 0.72;
uniform vec3 warm : source_color = vec3(1.10, 1.02, 0.86);
uniform vec3 cool : source_color = vec3(0.86, 0.95, 1.06);
uniform float vignette = 0.22;

const vec2 DISK[8] = vec2[](vec2(1.0, 0.0), vec2(0.707, 0.707), vec2(0.0, 1.0), vec2(-0.707, 0.707),
	vec2(-1.0, 0.0), vec2(-0.707, -0.707), vec2(0.0, -1.0), vec2(0.707, -0.707));

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen, uv).rgb;
	// One logical pixel in screen UV (the layout is 320x180).
	vec2 px = vec2(1.0 / 320.0, 1.0 / 180.0);
	if (blur_enabled) {
		float tilt = smoothstep(tilt_start, 1.0, abs(uv.y - 0.5) * 2.0);
		vec3 bright = vec3(0.0);
		vec3 blurred = col;
		for (int i = 0; i < 8; i++) {
			vec2 o = DISK[i];
			vec3 near = texture(screen, uv + o * px * tilt_radius * tilt).rgb;
			blurred += near;
			vec3 far = texture(screen, uv + o * px * 5.0).rgb;
			bright += max(far - vec3(bloom_threshold), vec3(0.0));
		}
		col = blurred / 9.0;
		col += bright / 8.0 * bloom_strength * 2.0;
	}
	// Grade: cool shadows, warm highlights, a touch more saturation.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(cool, warm, smoothstep(0.15, 0.75, luma));
	col = mix(vec3(luma), col, 1.12);
	col = col * col * (3.0 - 2.0 * col) * 0.22 + col * 0.78;  // gentle S-curve
	vec2 centred = uv - 0.5;
	float v = smoothstep(0.85, 0.25, length(centred * vec2(1.0, 0.85)));
	col *= mix(1.0 - vignette, 1.0, v);
	COLOR = vec4(col, 1.0);
}
