shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
    COLOR = mix(color, vec4(1.0 - color.rgb, color.a), intensity);
}