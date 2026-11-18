shader_type canvas_item;
// Moves a soft elliptical area of the texture (e.g. a writing hand) by offset_px,
// snapped to the 2x pixel grid, so a still painting can "write".

uniform vec2 center_px = vec2(312.0, 196.0);
uniform vec2 radius_px = vec2(36.0, 28.0);
uniform vec2 offset_px = vec2(0.0);
uniform float grid = 2.0;

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 p = UV * tex_size;
	vec2 d = (p - center_px) / radius_px;
	float w = smoothstep(0.0, 0.5, clamp(1.0 - dot(d, d), 0.0, 1.0));
	vec2 off = floor(offset_px * w / grid + 0.5) * grid;
	COLOR = texture(TEXTURE, (p - off) / tex_size);
}
