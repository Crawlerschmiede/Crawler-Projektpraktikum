shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_count : hint_range(0, 1080) = 240.0;
//  control the strength of the color bleed
uniform float aberration_amount : hint_range(0.0, 0.1) = 0.005; 

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // 1. Chromatic Aberration (The Color Bleed)
    // shift the Red channel to the right and the Blue channel to the left
    float dist = distance(uv, vec2(0.5)); // distance from center
	float amount = aberration_amount * dist;
	float r = texture(SCREEN_TEXTURE, vec2(uv.x + amount, uv.y)).r;
    float g = texture(SCREEN_TEXTURE, uv).g;
    float b = texture(SCREEN_TEXTURE, vec2(uv.x - amount, uv.y)).b;
    vec4 color = vec4(r, g, b, 1.0);
    
    // 2. Add Scanlines (CRT effect)
    float scanline = sin(uv.y * scanline_count * 3.14159) * 0.1;
    color.rgb -= scanline;
    
    // 3. Vignette (Darkened corners for dungeon feel)
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = pow(vignette * 15.0, 0.5);
    color.rgb *= vignette;
    
    // 4. Noise/Flicker
    color.rgb += (fract(sin(dot(uv, vec2(12.9898, 78.233) * TIME)) * 43758.5453) - 0.5) * 0.05;
    
    COLOR = color;
}