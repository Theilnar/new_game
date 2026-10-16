shader_type canvas_item;
render_mode unshaded;

// World-space fog layer for StationNearLitParallax2D.
// Unlike ScreenFog, this material does not sample the screen and is not camera-locked.
uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.52, 0.61, 0.64, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.18;
uniform float speed : hint_range(0.0, 0.08) = 0.018;
uniform float noise_scale : hint_range(0.1, 8.0) = 1.35;

void fragment() {
	vec2 drift = vec2(TIME * speed, -TIME * speed * 0.42);
	vec2 fog_uv = UV * vec2(noise_scale, noise_scale * 0.78) + drift;
	float broad_cloud = texture(noise_texture, fog_uv).r;
	float detail_cloud = texture(noise_texture, fog_uv * 2.1 + vec2(0.17, 0.31) - drift * 0.72).r;
	float cloud = mix(broad_cloud, detail_cloud, 0.22);
	float vertical_fade = smoothstep(0.02, 0.30, UV.y) * (1.0 - smoothstep(0.70, 1.0, UV.y));
	float edge_fade = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
	float fog_alpha = density * smoothstep(0.25, 0.78, cloud) * vertical_fade * edge_fade;
	COLOR = vec4(fog_color.rgb, fog_alpha);
}
