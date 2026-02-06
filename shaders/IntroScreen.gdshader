shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_count : hint_range(0, 1080) = 300.0;
uniform float scanline_intensity : hint_range(0, 1) = 0.1;
uniform float curvature : hint_range(0, 1) = 0.05;
uniform float vignette_intensity : hint_range(0, 1) = 0.4;

void fragment() {
    // 1. Curvature (Fish-eye effect)
    vec2 centered_uv = SCREEN_UV * 2.0 - 1.0;
    vec2 uv_offset = centered_uv.yx / 3.0;
    vec2 distorted_uv = SCREEN_UV + centered_uv * dot(uv_offset, uv_offset) * curvature;

    // Check if UV is out of bounds (black borders)
    if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 || distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        vec4 text = texture(SCREEN_TEXTURE, distorted_uv);

        // 2. Scanlines
        float scanline = sin(distorted_uv.y * scanline_count * PI * 2.0);
        text.rgb -= scanline * scanline_intensity;

        // 3. Vignette (Dark corners)
        float dist = distance(SCREEN_UV, vec2(0.45));
        text.rgb *= smoothstep(0.5, 0.5 - vignette_intensity, dist);

		// This creates a hard 'rounded corner' look
		//float mask = smoothstep(0.4, 0.39, abs(distorted_uv.x - 0.5)) * smoothstep(0.4, 0.39, abs(distorted_uv.y - 0.5));
		//text.rgb *= mask;

        COLOR = text;
    }
}