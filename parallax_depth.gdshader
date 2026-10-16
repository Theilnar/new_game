shader_type canvas_item;

// Subtle atmospheric blur for parallax background layers.
uniform float blur_pixels : hint_range(0.0, 4.0) = 0.0;
uniform float contrast : hint_range(0.0, 1.0) = 1.0;
uniform vec4 atmosphere : source_color = vec4(0.78, 0.86, 0.90, 0.0);
uniform float atmosphere_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_pixels;
	vec4 color = texture(TEXTURE, UV) * 4.0;
	color += texture(TEXTURE, UV + vec2(px.x, 0.0));
	color += texture(TEXTURE, UV - vec2(px.x, 0.0));
	color += texture(TEXTURE, UV + vec2(0.0, px.y));
	color += texture(TEXTURE, UV - vec2(0.0, px.y));
	color /= 8.0;

	color.rgb = mix(vec3(0.5), color.rgb, contrast);
	color.rgb = mix(color.rgb, atmosphere.rgb, atmosphere_strength);
	COLOR = color;
}
