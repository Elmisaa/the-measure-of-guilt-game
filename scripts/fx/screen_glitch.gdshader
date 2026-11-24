shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float intensity = 0.0;
uniform float saturation = 1.0;
uniform float pixel_block_size : hint_range(1.0, 4.0, 1.0) = 1.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

vec3 sample_frame(vec2 uv, vec2 texel) {
	if (pixel_block_size <= 1.0) {
		return texture(screen, uv).rgb;
	}
	vec2 block = texel * pixel_block_size;
	vec2 center = (floor(uv / block) + 0.5) * block;
	return texture(screen, clamp(center, texel * 0.5, 1.0 - texel * 0.5)).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 12.0);
	float row = floor(uv.y * 90.0);
	float r = hash(row * 13.1 + t * 7.3);
	if (r > 1.0 - intensity * 0.3) {
		uv.x += floor((hash(row + t) - 0.5) * 24.0 * intensity) / 160.0;
	}
	vec3 c = sample_frame(uv, SCREEN_PIXEL_SIZE);
	float n = hash(floor(uv.x * 160.0) * 3.1 + row * 7.7 + t);
	c += (n - 0.5) * 0.16 * intensity;
	c *= 1.0 - 0.1 * intensity * step(0.5, fract(uv.y * 90.0));
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, saturation);
	COLOR = vec4(c, 1.0);
}
