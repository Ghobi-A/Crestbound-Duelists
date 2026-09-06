shader_type canvas_item;
render_mode unshaded;
uniform bool magenta_key = false;

// The source atlas declares green-screen material explicitly. This is not a
// generic removal heuristic for ordinary textures; only registered art uses it.
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float excess_green = texel.g - max(texel.r, texel.b);
	float background = smoothstep(0.18, 0.45, excess_green);
	if (magenta_key) {
		// Keep dark violet cloth and emerald accents; only bright key pink is removed.
		background = smoothstep(0.45, 0.8, min(texel.r, texel.b) - texel.g);
	}
	COLOR.a *= 1.0 - background;
}
