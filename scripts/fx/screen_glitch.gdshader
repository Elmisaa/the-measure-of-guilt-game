shader_type canvas_item;
// Screen interference: random horizontal row tears + noise + faint scanlines.
// Rows are 4px (matches the 4x pixel of the frame). intensity 0..1.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float intensity = 0.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 12.0);
	float row = floor(uv.y * 90.0);
	float r = hash(row * 13.1 + t * 7.3);
	if (r > 1.0 - intensity * 0.3) {
		uv.x += floor((hash(row + t) - 0.5) * 24.0 * intensity) / 160.0;
	}
	vec3 c = texture(screen, uv).rgb;
	float n = hash(floor(uv.x * 160.0) * 3.1 + row * 7.7 + t);
	c += (n - 0.5) * 0.16 * intensity;
	c *= 1.0 - 0.1 * intensity * step(0.5, fract(uv.y * 90.0));
	COLOR = vec4(c, 1.0);
}
