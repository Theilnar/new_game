shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D noise_texture : repeat_enable, filter_nearest;
uniform vec4 water_color : source_color = vec4(0.18, 0.55, 0.08, 1.0);
uniform float water_opacity : hint_range(0.0, 1.0) = 0.58;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.32;
uniform float wave_strength = 0.035;
uniform float wave_speed = 0.7;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float ellipse = length(centered * vec2(1.0, 1.9));
	float puddle = 1.0 - smoothstep(0.4, 0.5, ellipse);

	vec2 noise_uv_a = UV * vec2(2.8, 5.0) + vec2(TIME * 0.025, -TIME * 0.04);
	vec2 noise_uv_b = UV * vec2(6.0, 3.0) - vec2(TIME * 0.035, TIME * 0.02);
	float noise_a = texture(noise_texture, noise_uv_a).r - 0.5;
	float noise_b = texture(noise_texture, noise_uv_b).r - 0.5;
	float distortion = (noise_a * 0.7 + noise_b * 0.3) * wave_strength;

	vec2 reflection_uv = vec2(
		SCREEN_UV.x + distortion + sin(TIME * wave_speed + UV.y * 16.0) * 0.006,
		1.0 - SCREEN_UV.y + distortion * 0.45
	);
	vec3 reflection = texture(screen_texture, reflection_uv).rgb;

	float boil = 0.5 + 0.5 * sin(TIME * 2.0 + noise_a * 7.0 + UV.x * 14.0);
	vec3 liquid = mix(water_color.rgb * 0.35, water_color.rgb * 1.35, boil * 0.5 + 0.25);
	liquid = mix(liquid, reflection, reflection_strength);
	COLOR = vec4(liquid, puddle * water_opacity);
}
