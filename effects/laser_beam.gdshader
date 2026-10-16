shader_type canvas_item;
render_mode blend_add;

uniform vec4 beam_color : source_color = vec4(0.15, 0.75, 1.0, 1.0);
uniform float glow_strength = 2.0;
uniform float noise_amount = 0.08;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float noise = (hash21(vec2(UV.x * 80.0, floor(TIME * 18.0))) - 0.5) * noise_amount;
	float pulse = 0.92 + sin(TIME * 24.0 + UV.x * 35.0) * 0.08;
	float edge = 1.0 - smoothstep(0.12, 0.5, abs(UV.y - 0.5));
	float alpha = COLOR.a * max(edge, 0.35) * pulse;
	COLOR = vec4(beam_color.rgb * (glow_strength + noise), alpha);
}
