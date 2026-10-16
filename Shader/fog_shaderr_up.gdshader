shader_type canvas_item;

uniform sampler2D noise_texture: repeat_enable,filter_nearest;
uniform float density: hint_range(0.0, 1.0) = 0.25;
uniform vec2 speed = vec2(0.0, -0.035);
uniform float top_fade: hint_range(0.01, 1.0) = 0.28;

void vertex() {
}

void fragment() {
	vec2 uv = UV + speed * TIME;
	float noise = texture(noise_texture, uv).r;
	float fog = clamp(noise * 2.0 - 1.0, 0.0, 1.0);
	float fade_to_top = smoothstep(0.0, top_fade, UV.y);
	COLOR.a = fade_to_top * fog * density;
}
