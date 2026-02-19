shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.4, 0.3, 0.1, 1.0); // Darker Gold
uniform vec4 highlight_color : source_color = vec4(1.0, 0.9, 0.5, 1.0); // Bright Gold
uniform float shimmer_speed : hint_range(0.0, 5.0) = 1.0;
uniform float shimmer_width : hint_range(0.1, 1.0) = 0.6;
uniform float is_hovered : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Create Metallic Vertical Gradient
    // darker at the bottom and lighter at the top
    float gradient = smoothstep(0.0, 1.0, UV.y);
    vec3 metallic_bg = mix(highlight_color.rgb, base_color.rgb, gradient);
    
    // Inner Border Glow
    // This creates a sharp highlight just inside the edges
    float border_thickness = 0.1;
    vec2 edge_dist = smoothstep(0.0, border_thickness, UV) * smoothstep(0.0, border_thickness, 1.0 - UV);
    float inner_border = 1.0 - (edge_dist.x * edge_dist.y);
    vec3 final_color = mix(metallic_bg, highlight_color.rgb, inner_border * 0.5);
    
    // Shimmer Effect (The Diagonal Sweep)
    // Moves a bright bar across the UVs based on TIME
    float time_sweep = fract(TIME * shimmer_speed * 0.2);
    float shimmer_pos = UV.x - UV.y + (time_sweep * 4.0 - 2.0);
    float shimmer = smoothstep(shimmer_width, 0.0, abs(shimmer_pos));
    
    // Only show shimmer if hovered or at intervals
    final_color += highlight_color.rgb * shimmer * 0.4;
    
    // Hover Brightness
    final_color *= (1.0 + (is_hovered * 0.3));
    
    COLOR = vec4(final_color, tex_color.a);
}