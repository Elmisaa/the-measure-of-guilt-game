shader_type spatial;
render_mode cull_disabled;
uniform sampler2D walnut : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D moulding : hint_normal, filter_nearest_mipmap, repeat_enable;
varying vec2 grain_uv;
void vertex() {
    grain_uv = vec2(UV.x * length(MODEL_MATRIX[0].xyz), UV.y);
}
void fragment() {
    vec2 uv = vec2(grain_uv.x, clamp(grain_uv.y, 0.5/96.0, 1.0-0.5/96.0));
    ALBEDO = texture(walnut, uv).rgb;
    NORMAL_MAP = texture(moulding, uv).rgb;
    NORMAL_MAP_DEPTH = 0.7;
    ROUGHNESS = 0.86;
}
