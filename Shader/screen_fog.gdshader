shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.56, 0.64, 0.66, 1.0);
uniform float density : hint_range(0.0, 0.18) = 0.045;
uniform float speed : hint_range(0.0, 0.08) = 0.006;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 drift = vec2(TIME * speed, -TIME * speed * 0.42);
	// Use a seamless filtered noise texture for the main fog body. Two very
	// different scales make the motion feel like soft drifting mist instead
	// of a visible grid of procedural cells.
	vec2 slow_uv = uv * vec2(1.65, 1.05) + drift;
	vec2 detail_uv = uv * vec2(3.25, 2.10) - drift * 0.72 + vec2(0.17, 0.31);
	float broad_cloud = texture(noise_texture, slow_uv).r;
	float detail_cloud = texture(noise_texture, detail_uv).r;
	float cloud = mix(broad_cloud, detail_cloud, 0.22);
	float vertical_fade = smoothstep(0.05, 0.75, uv.y);
	float edge_fade = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
	float fog_alpha = density * smoothstep(0.25, 0.82, cloud) * vertical_fade * edge_fade;
	vec4 scene = texture(screen_texture, uv);
	COLOR = vec4(mix(scene.rgb, fog_color.rgb, fog_alpha), scene.a);
}
