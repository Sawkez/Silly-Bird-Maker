shader_type canvas_item;

uniform vec2 scale;

void fragment() {
	COLOR = texture(TEXTURE, UV * scale);
}
