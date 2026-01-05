shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 color = texture(SCREEN_TEXTURE, uv);
    
    // Create a circular mask (0.0 at center, 1.0 at edges)
    float dist = distance(uv, vec2(0.5, 0.5));
    
    // Add a "pulse" using TIME to simulate flickering fire
    float flicker = sin(TIME * 6.0) * 0.02; 
    float vignette = smoothstep(0.4 + flicker, 0.8 + flicker, dist);
    
    // Darken the color based on the vignette, but keep some detail
    color.rgb = mix(color.rgb, color.rgb * 0.1, vignette);
    
    COLOR = color;
}