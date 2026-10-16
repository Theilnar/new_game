shader_type canvas_item;

// Шейдер силуэтной тени для Sprite2D.
// Назначается вручную через CanvasItemMaterial -> Shader.

uniform vec4 shadow_color : source_color = vec4(0.01, 0.008, 0.015, 0.42);
uniform float softness : hint_range(0.0, 8.0, 0.1) = 2.5;
uniform vec2 light_position = vec2(0.0);
uniform float light_radius : hint_range(1.0, 2000.0, 1.0) = 250.0;
uniform float light_strength : hint_range(0.0, 2.0, 0.01) = 1.0;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE * softness;
	float alpha = 0.0;

	// Центральная выборка и соседние выборки смягчают край силуэта.
	alpha += texture(TEXTURE, UV).a * 0.40;
	alpha += texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a * 0.10;
	alpha += texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a * 0.10;
	alpha += texture(TEXTURE, UV + vec2(0.0, pixel.y)).a * 0.10;
	alpha += texture(TEXTURE, UV - vec2(0.0, pixel.y)).a * 0.10;
	alpha += texture(TEXTURE, UV + pixel).a * 0.05;
	alpha += texture(TEXTURE, UV - pixel).a * 0.05;
	alpha += texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a * 0.05;
	alpha += texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a * 0.05;

	float distance_to_light = distance(world_position, light_position);
	float light_fade = 1.0 - smoothstep(0.0, light_radius, distance_to_light);
	light_fade *= light_strength;

	// Внутри радиуса источника тень постепенно исчезает.
	float final_alpha = alpha * shadow_color.a * (1.0 - clamp(light_fade, 0.0, 1.0));
	COLOR = vec4(shadow_color.rgb, final_alpha);
}
