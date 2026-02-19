shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float glow_power : hint_range(0.0, 10.0) = 1.5;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.0;

uniform vec4 exclude_color_1 : source_color = vec4(0.014, 0.013, 0.016, 1.0); 
uniform vec4 exclude_color_2 : source_color = vec4(0.0, 0.0, 0.0, 1.0); 
uniform float color_threshold : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // 1. Calculate the exclusion mask
    float dist1 = distance(tex_color.rgb, exclude_color_1.rgb);
    float dist2 = distance(tex_color.rgb, exclude_color_2.rgb);
    
    float glow_mask = 1.0;
    if (dist1 < color_threshold || dist2 < color_threshold) {
        glow_mask = 0.0;
    }

    float breathe = (sin(TIME * speed) * 0.5) + 0.5;
    float flicker = fract(sin(dot(vec2(TIME), vec2(12.9898, 78.233))) * 43758.5453);
    float light_surge = (breathe * 0.8 + 0.2) + (flicker * flicker_intensity);
    
    vec3 glow = tex_color.rgb * light_surge * glow_power * glow_mask;
    

    vec3 final_rgb = tex_color.rgb + glow;
    
    COLOR = vec4(final_rgb, tex_color.a);
}