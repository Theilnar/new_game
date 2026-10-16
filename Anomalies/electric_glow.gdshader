shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(0.12, 0.72, 1.0, 1.0);
uniform float glow_strength = 2.2;
uniform float spread = 5.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float halo = 0.0;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * spread;

	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * step_uv * 0.5;
			halo = max(halo, texture(TEXTURE, UV + offset).a);
		}
	}

	float flicker = 0.9 + sin(TIME * 22.0) * 0.1;
	float alpha = max(source.a * 0.35, halo * 0.62) * flicker;
	COLOR = vec4(glow_color.rgb * alpha * glow_strength, alpha);
}
