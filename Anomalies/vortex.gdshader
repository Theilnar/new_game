shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 anomaly_color : source_color = vec4(0.24, 0.42, 0.48, 1.0);
uniform float distortion_strength : hint_range(0.0, 0.12) = 0.035;
uniform float swirl_speed : hint_range(0.0, 8.0) = 2.4;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered) * 2.0;
	float inside = 1.0 - smoothstep(0.72, 1.0, radius);
	vec2 radial = centered / max(length(centered), 0.001);
	float angle = atan(centered.y, centered.x);

	float swirl = sin(angle * 7.0 - TIME * swirl_speed + radius * 18.0);
	float ring = smoothstep(0.62, 0.9, radius) * (1.0 - smoothstep(0.9, 1.0, radius));
	vec2 offset = radial * distortion_strength * inside * (0.65 + swirl * 0.35);
	vec4 background = textureLod(screen_texture, SCREEN_UV + offset, 0.0);

	float tint_amount = inside * (0.08 + ring * 0.18);
	vec3 color = mix(background.rgb, anomaly_color.rgb, tint_amount);
	color += anomaly_color.rgb * ring * (0.06 + 0.04 * sin(TIME * 3.0 + angle * 5.0));

	COLOR = vec4(color, inside * (0.18 + ring * 0.2));
}
