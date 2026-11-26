shader_type canvas_item;
// The location behind a staged story scene: the live screen, softened,
// desaturated and sunk toward the night-navy surface colour so the
// characters and the dialogue panel carry the frame. `fade` eases it in.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float dim : hint_range(0.0, 1.0) = 0.5;
uniform vec2 step_uv = vec2(0.0072, 0.0128); // ~2.3 logical px at 320x180
uniform vec4 tint : source_color = vec4(0.03, 0.045, 0.08, 1.0);

void fragment() {
	vec3 sharp = texture(screen_tex, SCREEN_UV).rgb;
	vec3 sum = vec3(0.0);
	float weight = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float k = 1.0 / (1.0 + float(x * x + y * y));
			sum += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * step_uv, 2.0).rgb * k;
			weight += k;
		}
	}
	vec3 soft = sum / weight;
	float luma = dot(soft, vec3(0.299, 0.587, 0.114));
	soft = mix(soft, vec3(luma), 0.3);
	soft = mix(soft, tint.rgb, dim);
	// Darker toward the edges and the floor, where the panel sits.
	float vignette = smoothstep(0.95, 0.25, distance(SCREEN_UV, vec2(0.5, 0.4)));
	soft *= mix(0.62, 1.0, vignette);
	COLOR = vec4(mix(sharp, soft, fade), 1.0);
}
