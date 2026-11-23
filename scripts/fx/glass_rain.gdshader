shader_type canvas_item;

uniform float rain = 1.0;
uniform vec2 grid = vec2(320.0, 180.0);
uniform vec2 lamp_uv = vec2(-1.0, -1.0);
uniform float lamp_energy = 0.0;
uniform float seed = 0.0;
uniform float slant = 0.08;
uniform float density = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float layer(vec2 uv, float cols, float speed, float len, float dens, float s) {
	vec2 p = vec2(uv.x * cols + uv.y * cols * slant, uv.y * 3.0 - TIME * speed);
	float col = floor(p.x);
	float off = hash(vec2(col, s)) * 13.0;
	float row = floor(p.y + off);
	float fy = fract(p.y + off);
	float on = step(1.0 - dens * density, hash(vec2(col * 1.3, row + s)));
	float body = smoothstep(0.0, len, fy) * (1.0 - smoothstep(len, len + 0.02, fy));
	return on * body * (0.5 + 0.5 * fy / max(len, 0.01));
}

void fragment() {
	vec2 q = (floor(UV * grid) + 0.5) / grid;
	vec4 c = texture(TEXTURE, q);
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float glass = smoothstep(0.01, 0.09, c.b - c.r) * (1.0 - smoothstep(0.45, 0.7, luma));
	float r = layer(q, 150.0, 2.6, 0.22, 0.10, 3.0 + seed) * 0.55 + layer(q, 90.0, 3.6, 0.32, 0.06, 7.0 + seed * 1.7) * 0.8;
	vec3 col = c.rgb + vec3(0.55, 0.65, 0.82) * r * glass * rain * 0.45;
	if (lamp_uv.x >= 0.0) {
		vec2 d = (q - lamp_uv) * vec2(1.78, 1.0);
		float g = exp(-dot(d, d) * 9.0);
		col += vec3(1.0, 0.62, 0.3) * g * lamp_energy * 0.35;
	}
	COLOR = vec4(col, c.a);
}
