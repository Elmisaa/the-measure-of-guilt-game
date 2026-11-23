shader_type canvas_item;

uniform sampler2D mask_tex : filter_nearest;
uniform vec2 offset_px = vec2(0.0);
uniform float grid = 2.0;

float in_mask(vec2 p, vec2 tex_size) {
	return texture(mask_tex, p / tex_size).a;
}

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 p = UV * tex_size;
	vec2 off = floor(offset_px / grid + 0.5) * grid;
	vec2 src = p - off;
	if (in_mask(src, tex_size) > 0.5) {
		COLOR = texture(TEXTURE, src / tex_size);
	} else if (in_mask(p, tex_size) > 0.5) {
		vec2 q = p;
		for (int k = 0; k < 12; k++) {
			q.x -= grid;
			if (in_mask(q, tex_size) < 0.5) {
				break;
			}
		}
		COLOR = texture(TEXTURE, q / tex_size);
	} else {
		COLOR = texture(TEXTURE, UV);
	}
}
