shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec2 size = vec2(14.0, 6.0);
uniform float strength = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float layer(vec2 m, float cols_per_m, float speed, float len, float density, float seed) {
	vec2 p = vec2(m.x * cols_per_m + m.y * cols_per_m * 0.06, m.y * 1.2 - TIME * speed);
	float col = floor(p.x);
	float thin = step(fract(p.x), 0.18);
	float off = hash(vec2(col, seed)) * 11.0;
	float row = floor(p.y + off);
	float fy = fract(p.y + off);
	float on = step(1.0 - density, hash(vec2(col * 1.7, row + seed)));
	return on * thin * smoothstep(0.0, len * 0.3, fy) * (1.0 - smoothstep(len, len + 0.02, fy));
}

void fragment() {
	vec2 m = vec2(UV.x * size.x, -(1.0 - UV.y) * size.y);
	float r = layer(m, 22.0, 3.0, 0.22, 0.10, 3.0) * 0.45 + layer(m, 14.0, 4.2, 0.3, 0.07, 9.0) * 0.6;
	ALBEDO = vec3(0.55, 0.62, 0.75) * r * strength * 0.35;
	ALPHA = 1.0;
}
