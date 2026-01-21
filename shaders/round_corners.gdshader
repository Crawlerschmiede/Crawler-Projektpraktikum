shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    vec2 center_uv = (UV - 0.5) * 2.0;

    // We only apply the rounding logic if we aren't in the Top-Left quadrant
    // Top-left is where UV.x < 0.5 and UV.y < 0.5
    bool is_top_left = UV.x < 0.5 && UV.y < 0.5;

    float alpha = 1.0;

    if (!is_top_left) {
        vec2 size = vec2(1.0) - vec2(radius);
        // Using abs(center_uv) normally rounds all 4.
        // By checking is_top_left, we skip the math for that corner.
        vec2 dist_vec = max(abs(center_uv) - size, 0.0);
        float dist = length(dist_vec);
        alpha = 1.0 - smoothstep(radius - 0.01, radius, dist);
    }

    COLOR = vec4(COLOR.rgb, alpha * COLOR.a);
}