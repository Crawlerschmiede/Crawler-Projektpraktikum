shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float r_offset : hint_range(-0.05, 0.05) = 0.002;
uniform float b_offset : hint_range(-0.05, 0.05) = -0.002;
uniform float burn_intensity : hint_range(0.0, 1.0) = 0.1;

// Circle Controls
uniform float circle_radius : hint_range(0.0, 1.0) = 0.55;
uniform float circle_softness : hint_range(0.0, 0.5) = 0.5;

void fragment() {
    // 1. RGB Offset (Chromatic Aberration)
    float r = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(r_offset, 0.0)).r;
    float g = texture(SCREEN_TEXTURE, SCREEN_UV).g;
    float b = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(b_offset, 0.0)).b;
    
    vec3 color = vec3(r, g, b);
    
    // 2. Color Burn Effect
    vec3 burn = 1.0 - (1.0 - color) / max(vec3(0.01), (1.0 - burn_intensity));
    color = mix(color, burn, burn_intensity);
    
    // 3. Circular Mask
    // Calculate distance from the center of the screen
    float dist = distance(SCREEN_UV, vec2(0.5));
    
    // Create the circle mask
    // If dist > radius, the value becomes 0 (black)
    float mask = smoothstep(circle_radius, circle_radius - circle_softness, dist);
    
    // Apply the circle mask
    color *= mask;
    
    COLOR = vec4(color, 1.0);
}