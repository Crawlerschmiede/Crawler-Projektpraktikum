shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float glow_power : hint_range(0.0, 10.0) = 1.5;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.0;

uniform vec4 exclude_color_1 : source_color = vec4(0.014, 0.013, 0.016, 1.0); 
uniform vec4 exclude_color_2 : source_color = vec4(0.0, 0.0, 0.0, 1.0); 
uniform float color_threshold : hint_range(0.0, 1.0) = 0.3;


uniform float border_width : hint_range(0.0, 0.2) = 0.1;
uniform float border_segment_length : hint_range(0.1, 10.0) = 4.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // the exclusion mask
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


    float left = step(UV.x, border_width);
    float right = step(1.0 - border_width, UV.x);
    float top = step(UV.y, border_width);
    float bottom = step(1.0 - border_width, UV.y);
    float border_mask = clamp(left + right + top + bottom, 0.0, 1.0);
    
    
    vec2 centered_uv = UV - vec2(0.5);
    float angle = atan(centered_uv.y, centered_uv.x); // Range -PI to PI
    float crawl = sin(angle * border_segment_length + TIME * speed * 2.0);
    crawl = step(0.0, crawl); // Convert to sharp on/off segments
    
    vec3 border_final = border_color.rgb * border_mask * crawl * light_surge;


    vec3 final_rgb = tex_color.rgb + glow + border_final;
    
    
    float final_alpha = max(tex_color.a, border_mask * crawl * border_color.a);
    
    COLOR = vec4(final_rgb, final_alpha);
}