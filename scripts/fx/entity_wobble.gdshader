shader_type canvas_item;

uniform float amount = 1.0;
uniform float speed = 1.0;
uniform float pulse = 0.0;

void fragment() {
	float t = TIME * speed;
	float edge = 1.0 - smoothstep(0.0, 0.35, abs(UV.x - 0.5) * 2.0 - 0.3);
	vec2 off = vec2(sin(UV.y * 40.0 + t * 6.0) * 0.012, cos(UV.x * 30.0 + t * 4.0) * 0.006) * amount * (1.0 - edge * 0.6);
	vec4 c = texture(TEXTURE, UV + off);
	c.rgb *= 1.0 - pulse * 0.4;
	c.a *= 0.9 + 0.1 * sin(t * 3.0 + UV.y * 10.0);
	COLOR = c;
}
