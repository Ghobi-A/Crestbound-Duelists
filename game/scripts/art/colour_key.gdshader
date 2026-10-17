shader_type canvas_item;
render_mode unshaded;
uniform bool magenta_key = false;
uniform bool use_colour_key = true;
// Vertex colour already carries modulate/self_modulate (fades, hit flashes,
// dimming); the fragment replaces only the texture sample.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

// The source atlas declares green-screen material explicitly. This is not a
// generic removal heuristic for ordinary textures; only registered art uses it.
float key_background(vec3 texel) {
	if (magenta_key) {
		// Keep dark violet cloth and emerald accents; only bright key pink is removed.
		return smoothstep(0.45, 0.8, min(texel.r, texel.b) - texel.g);
	}
	return smoothstep(0.18, 0.45, texel.g - max(texel.r, texel.b));
}

// Premultiplied, keyed source texel. texelFetch ignores the node's filter,
// so the key is applied before any averaging and never leaves a fringe.
vec4 keyed_texel(sampler2D source, ivec2 point, ivec2 size) {
	vec4 texel = texelFetch(source, clamp(point, ivec2(0), size - ivec2(1)), 0);
	if (use_colour_key) {
		float key = key_background(texel.rgb);
		float edge = 0.0;
		// Despill only beside keyed background: legitimate violet cloth inside
		// the silhouette keeps its colour. Do this before premultiplied filtering.
		for (int axis = 0; axis < 4; axis++) {
			ivec2 delta = ivec2(1, 0);
			if (axis == 1) { delta = ivec2(-1, 0); }
			if (axis == 2) { delta = ivec2(0, 1); }
			if (axis == 3) { delta = ivec2(0, -1); }
			vec4 neighbour = texelFetch(source, clamp(point + delta, ivec2(0), size - ivec2(1)), 0);
			edge = max(edge, max(key_background(neighbour.rgb), 1.0 - neighbour.a));
		}
		texel.a *= 1.0 - key;
		if (magenta_key) {
			float spill = max(0.0, min(texel.r, texel.b) - texel.g);
			texel.rgb -= vec3(spill, 0.0, spill) * edge;
		} else {
			float spill = max(0.0, texel.g - max(texel.r, texel.b));
			texel.g -= spill * edge;
		}
	}
	return vec4(texel.rgb * texel.a, texel.a);
}

void fragment() {
	// Registered sheets are 1-2k px sources drawn at 2x-6x of the 320x180
	// layout. Box-filter the source texels under each output pixel (up to
	// 4x4 taps) so the art stays sharp at 1080p and alias-free at 360p.
	ivec2 size = textureSize(TEXTURE, 0);
	vec2 texel_uv = UV * vec2(size);
	vec2 footprint = max(fwidth(texel_uv), vec2(1.0));
	int taps = int(clamp(ceil(max(footprint.x, footprint.y)), 1.0, 4.0));
	vec4 sum = vec4(0.0);
	for (int j = 0; j < 4; j++) {
		if (j >= taps) {
			break;
		}
		for (int i = 0; i < 4; i++) {
			if (i >= taps) {
				break;
			}
			vec2 offset = ((vec2(float(i), float(j)) + 0.5) / float(taps) - 0.5) * footprint;
			sum += keyed_texel(TEXTURE, ivec2(floor(texel_uv + offset)), size);
		}
	}
	sum /= float(taps * taps);
	vec3 rgb = sum.a > 0.0 ? sum.rgb / sum.a : vec3(0.0);
	COLOR = vec4(rgb, sum.a) * tint;
}
