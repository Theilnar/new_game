shader_type canvas_item;

uniform float cutoff : hint_range(0.0, 1.0) = 0.58;

void fragment() {
	if (UV.y < cutoff) {
		discard;
	}
	COLOR = texture(TEXTURE, UV) * COLOR;
}
