shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 center = vec2(0.5);
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float radius = 0.35;
uniform float thickness = 0.035;
uniform float distortion = 0.025;
uniform vec4 ring_color : source_color = vec4(0.25, 0.85, 1.0, 1.0);

void fragment() {
	vec2 delta = UV - center;
	float distance_to_center = length(delta);
	float ring = 1.0 - smoothstep(thickness, thickness * 0.15, abs(distance_to_center - radius * progress));
	float falloff = 1.0 - smoothstep(0.0, 1.0, progress);
	vec2 direction = distance_to_center > 0.001 ? normalize(delta) : vec2(0.0);
	vec2 warped_uv = UV + direction * ring * distortion * falloff;
	vec4 scene = texture(screen_texture, warped_uv);
	COLOR = vec4(scene.rgb + ring_color.rgb * ring * falloff, 1.0);
}
