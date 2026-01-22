shader_type canvas_item;

uniform float shine_progress : hint_range(0.0, 1.0) = 0.0;
uniform float shine_size : hint_range(0.01, 1.0) = 0.1;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float shine = step(1.0 - shine_progress, UV.x + UV.y) * step(UV.x + UV.y, 1.0 - shine_progress + shine_size);
    COLOR.rgb = mix(tex.rgb, shine_color.rgb, shine * tex.a);
    COLOR.a = tex.a;
}