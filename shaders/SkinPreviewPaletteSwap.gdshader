shader_type canvas_item;

uniform vec3[10] palette;

const float COLOR_INDEX_MULT = 255.0 / float(0x10);

void fragment() {
	int index = int(COLOR.r * COLOR_INDEX_MULT);
	if (index < 11) {
		COLOR.rgb = palette[index];
	}
}