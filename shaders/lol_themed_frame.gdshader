shader_type canvas_item;

uniform vec4 frame_color : source_color = vec4(0.7, 0.55, 0.2, 1.0); // Gold/Bronze
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.8); // Deep recess
uniform float border_thickness : hint_range(0.0, 0.2) = 0.05;
uniform float bevel_intensity : hint_range(0.0, 1.0) = 0.4;

void fragment() {
    // frame area
    float l = step(UV.x, border_thickness);
    float r = step(1.0 - border_thickness, UV.x);
    float t = step(UV.y, border_thickness);
    float b = step(1.0 - border_thickness, UV.y);
    float frame_mask = clamp(l + r + t + b, 0.0, 1.0);
    
    // Inner Shadow
    float inner_thick = border_thickness + 0.03;
    float il = step(UV.x, inner_thick);
    float ir = step(1.0 - inner_thick, UV.x);
    float it = step(UV.y, inner_thick);
    float ib = step(1.0 - inner_thick, UV.y);
    float inner_mask = clamp(il + ir + it + ib, 0.0, 1.0);

    float highlight = (1.0 - UV.x) * (1.0 - UV.y);
    vec3 metallic_gradient = mix(frame_color.rgb * (1.0 - bevel_intensity), frame_color.rgb * (1.0 + bevel_intensity), highlight);
    
    // Combine Layers

    vec3 final_rgb = shadow_color.rgb;
    
    // Mix in the metallic frame color based on the frame mask
    final_rgb = mix(final_rgb, metallic_gradient, frame_mask);
    
    float alpha = inner_mask;
    
    COLOR = vec4(final_rgb, alpha);
}