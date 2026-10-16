shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D noise_texture : repeat_enable, filter_nearest;
uniform vec4 deep_color : source_color = vec4(0.04, 0.16, 0.03, 1.0);
uniform vec4 acid_color : source_color = vec4(0.42, 0.95, 0.08, 1.0);
uniform float boil_speed = 1.8;
uniform vec2 noise_speed = vec2(0.035, 0.018);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float ellipse = length(centered * vec2(1.0, 1.9));
	float puddle = 1.0 - smoothstep(0.38, 0.5, ellipse);

	vec2 noise_uv_a = UV * 2.6 + noise_speed * TIME * boil_speed;
	vec2 noise_uv_b = UV * 5.2 - noise_speed.yx * TIME * boil_speed * 1.35;
	float noise_a = texture(noise_texture, noise_uv_a).r;
	float noise_b = texture(noise_texture, noise_uv_b).r;
	float noise = clamp(noise_a * 0.65 + noise_b * 0.35, 0.0, 1.0);
	float bubbles = smoothstep(0.62, 0.86, noise);
	float energy = clamp(0.12 + noise * 0.62 + bubbles * 0.28, 0.0, 1.0);

	vec3 liquid = mix(deep_color.rgb, acid_color.rgb, energy);
	float rim = smoothstep(0.5, 0.34, ellipse) * 0.35;
	COLOR = vec4(liquid + acid_color.rgb * rim, puddle * (0.42 + energy * 0.46));
}
