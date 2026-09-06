shader_type canvas_item;
render_mode unshaded;
uniform bool magenta_key = false;

// The source atlas declares green-screen material explicitly. This is not a
// generic removal heuristic for ordinary textures; only registered art uses it.
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	// How much the pixel leans on the key's own channels. For a texel that
	// is a blend of subject and key, this runs roughly linearly from the
	// subject's own value up to 1 at pure key, so it doubles as a coverage
	// estimate rather than only a yes/no test.
	float excess;
	float brightness;
	vec3 key;
	if (magenta_key) {
		excess = min(texel.r, texel.b) - texel.g;
		brightness = max(texel.r, texel.b);
		key = vec3(1.0, 0.0, 1.0);
	} else {
		excess = texel.g - max(texel.r, texel.b);
		brightness = texel.g;
		key = vec3(0.0, 1.0, 0.0);
	}
	// Two conditions, so partially-keyed edge pixels are removed in
	// proportion without eating the art. The old single hard band started
	// at 0.45 and left every edge texel below it fully opaque and
	// magenta-tinted; about 3% of the atlas sits in that range, which is
	// exactly the halo around each sprite. Brightness is what separates
	// the key from the subject: the key is a bright screen colour, while
	// the dark violet cloth and emerald accents this must preserve are
	// nowhere near as luminous.
	float background = smoothstep(0.15, 0.85, excess) * smoothstep(0.30, 0.55, brightness);
	float alpha = 1.0 - background;
	// Removing the key from alpha alone leaves its colour in the RGB of
	// every partially-keyed pixel, which reads as a coloured fringe around
	// the subject. That stayed invisible while these sprites were being
	// downscaled about tenfold onto a 320x180 canvas, and became obvious
	// once they were drawn near their authored size with smooth filtering.
	// An edge texel is texel = alpha * subject + (1 - alpha) * key, so
	// solving for subject takes the key back out.
	//
	// COLOR already carries the sprite's modulate (the hit-flash tint, the
	// entity's translucency), and MODULATE itself is not exposed under the
	// gl_compatibility renderer this project targets. Since modulate is a
	// per-channel multiply, applying the correction as a ratio against the
	// raw texel preserves it exactly.
	if (alpha > 0.003) {
		vec3 subject = clamp((texel.rgb - key * (1.0 - alpha)) / alpha, 0.0, 1.0);
		vec3 safe = max(texel.rgb, vec3(0.0001));
		COLOR.rgb *= clamp(subject / safe, 0.0, 1.0);
	}
	COLOR.a *= alpha;
}
