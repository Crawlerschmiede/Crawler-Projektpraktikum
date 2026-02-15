shader_type canvas_item;

// These will show up in your Inspector under "Shader Parameters"
uniform vec4 old_paper_color : source_color;
uniform vec4 old_wood_color : source_color;
uniform vec4 old_lines_color : source_color;

uniform vec4 new_paper_color : source_color;
uniform vec4 new_wood_color : source_color;
uniform vec4 new_lines_color : source_color;

uniform float precision : hint_range(0.0, 1.0) = 0.12;

void fragment() {
    vec4 current_color = texture(TEXTURE, UV);
    
    // Check if the current pixel matches the old paper color
    if (distance(current_color.rgb, old_paper_color.rgb) < precision) {
        COLOR = vec4(new_paper_color.rgb, current_color.a);
    } 
    // Check if it matches the old wood/handle color
    else if (distance(current_color.rgb, old_wood_color.rgb) < precision) {
        COLOR = vec4(new_wood_color.rgb, current_color.a);
    }
	    else if (distance(current_color.rgb, old_lines_color.rgb) < precision) {
        COLOR = vec4(new_lines_color.rgb, current_color.a);
    }
    else {
        COLOR = current_color;
    }
}