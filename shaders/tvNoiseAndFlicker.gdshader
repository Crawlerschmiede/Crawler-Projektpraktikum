shader_type canvas_item;

uniform float noise_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float flicker_speed : hint_range(0.0, 50.0) = 20.0;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    float n = random(UV + TIME);
    float flicker = sin(TIME * flicker_speed) * 0.1;
    vec4 color = vec4(vec3(n), 1.0);
    COLOR = color * noise_intensity + flicker;
}