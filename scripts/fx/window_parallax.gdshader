shader_type canvas_item;
// Hall windows with depth: where mask is white the city strip shows through, shifted by the camera
// (offset_px, already snapped to the art grid in GDScript); frames, column and the room stay put.
// Made by tools/make_window_parallax.py.

uniform sampler2D mask_tex : filter_nearest;
uniform sampler2D city_tex : filter_nearest;
uniform vec2 bg_size = vec2(2012.0, 360.0);
uniform vec2 city_origin = vec2(428.0, 96.0);  // where the strip's top-left sits in the hall (offset 0)
uniform vec2 city_size = vec2(428.0, 108.0);
uniform float offset_px = 0.0;
uniform float keep_glass = 0.18;  // a little of the painted glass (haze, reflections) over the city

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (texture(mask_tex, UV).r > 0.5) {
		vec2 px = floor(UV * bg_size);
		vec2 cp = px - city_origin + vec2(offset_px, 0.0);
		vec3 city = texture(city_tex, (cp + 0.5) / city_size).rgb;
		COLOR = vec4(mix(city, base.rgb, keep_glass), 1.0);
	} else {
		COLOR = base;
	}
}
