shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float value = 0.0;
uniform float scale_y;
uniform float zoom_y;

uniform float wave_amplitude;
uniform float wave_speed;
uniform float wave_period;

uniform sampler2D noise;
uniform vec2 distortion_scale;
uniform float distortion_intencity;
uniform float distortion_speed;

uniform sampler2D fadeGradient;
uniform vec4 water_color:source_color;

render_mode unshaded;

/*uniform sampler2D gradient;*/
uniform float mix_amount = 1.0;
/*uniform sampler2D fadeGradient: hint_black;
/*uniform vec4 some_color : source_color = vec4(1.0);*/
/*uniform vec4 my_color;*/
/*uniform vec4 other_color : hint_color;*/



void fragment() {
	float wave = sin(TIME*1.0-UV.x * 50.0);
	float wave2 = sin(TIME + 0.1);
	float waves = UV.y + sin(UV.x / wave_period + TIME + wave_speed) * wave_amplitude;
	float uv_height = SCREEN_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.y;
	float distortion = (textureLod(noise, UV * distortion_scale + wave * distortion_speed, 0.0).x -0.5) * distortion_intencity;
	// Reflect the scene around the water surface (UV.y == 0), not around
	// the screen centre. scale_y is supplied by the water Sprite2D material.
	float sprite_scale_y = abs(scale_y);
	float reflection_offset = uv_height * UV.y * 2.0 * sprite_scale_y;
	vec2 reflection_screen_uv = vec2(SCREEN_UV.x - distortion, SCREEN_UV.y - reflection_offset);
	vec4 reflection = textureLod(screen_texture, reflection_screen_uv, 0.0);
	/*COLOR.rgb = mix(reflection.rgb, water_color.rgb, water_color.a);*/
	/*COLOR = vec3(1.0, 0.0, 1.0);*/
	/*COLOR = reflection * some_color;*/
	/*vec4 reflection=textureLod(screen_texture,reflected,1.0);*/
	COLOR.rgb=mix(reflection.rgb,water_color.rgb,water_color.a);
	/*vec4 gradient= texture(fadeGradient, UV);*/
	COLOR.a = clamp(0.72 - UV.y * 0.52, 0.18, 0.72); /* плавное затухание отражения */

	/*COLOR.rgb = vec3(waves);*/
  /*vec4 color = texture(TEXTURE, UV);*/
	/*vec4 input_color = texture(TEXTURE, UV);*/

	/*float grayscale_value = 5.5;*/

	/*COLOR.rgb = sampled_color;*/
	/*COLOR.rgb = mix(input_color.rgb, sampled_color, mix_amount);*/

	/*vec4 input_color = texture(TEXTURE, UV);
	float greyscale_value = dot(input_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 sampled_color = texture(fadeGradient, vec2(greyscale_value, 0.0)).rgb;

	/*COLOR.rgb = mix(input_color.rgb, sampled_color, mix_amount);*/

}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
