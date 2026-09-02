shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float level : hint_range(0.0, 1.0) = 0.5; 
uniform vec4 water_albedo : source_color = vec4(0.26, 0.23, 0.73, 1.0);
uniform float water_opacity : hint_range(0.0, 1.0) = 0.35;
uniform float water_speed = 0.05;
uniform float wave_distortion = 0.2;
uniform int wave_multiplyer = 7;
uniform bool water_texture_on = true;
uniform float reflection_X_offset = 0.0;
uniform float reflection_Y_offset = 0.0;
uniform sampler2D noise_texture : hint_normal;
uniform sampler2D noise_texture2 : hint_normal;

uniform vec2 speed = vec2(0.02, 0.01);//new
uniform sampler2D tile;

void fragment() {
	vec2 uv = UV;
	COLOR = vec4(0.0);
	
	
	if (uv.y >= level) {
		COLOR.a = 1.0;
		

		//float col = texture(tile, UV+vec2(TIME, 0.0)).x;
		//COLOR = texture(TEXTURE, UV + (col/10.0));

		float wave1 = sin(TIME*1.0-UV.x * 50.0);
		
		// distorted reflections
		vec2 water_uv = vec2(uv.x, uv.y * float(wave_multiplyer));
		float noise = texture(noise_texture, vec2(water_uv.x + wave1 * water_speed, water_uv.y )).x * wave_distortion;
		//float noise = texture(noise_texture, vec2(water_uv.x + TIME * water_speed, water_uv.y )).x * wave_distortion;
		noise -= (0.5 * wave_distortion);
		
		
		// water texture
		if (water_texture_on) {
			float water_texture_limit = 0.35;
			vec4 water_texture = texture(noise_texture2, uv * vec2(0.5, 4.0) + vec2(noise, 0.0));
			float water_texture_value = (water_texture.x < water_texture_limit) ? 1.0 : 0.0;	
			COLOR.xyz = vec3(water_texture_value);
		}
		
	//	float wave = sin(TIME* 3.0+UV.x * 20.0);
	//	vec4 sprite = texture(TEXTURE, UV + vec2(0.0, wave/20.0));
	//	COLOR = sprite;
		
		// putting everything toghether 
		vec4 current_texture = texture(screen_texture, vec2(SCREEN_UV.x + noise + reflection_X_offset, 1.0 - SCREEN_UV.y - (level - 0.5) * 2.0 + reflection_Y_offset));
		/*vec4 current_texture = texture(screen_texture, vec2(SCREEN_UV.x + noise + reflection_X_offset, 1.0 - SCREEN_UV.y - (level - 0.5) * 2.0 + reflection_Y_offset));*/
		COLOR = mix(COLOR, current_texture,0.5);
		COLOR = mix(COLOR, water_albedo, water_opacity);
		COLOR.a = 0.8 - UV.y; /*градиент альфа канала*/
		
		

	}
}
/*uniform vec2 scale;
uniform float y_zoom;
uniform sampler2D noise;
uniform vec2 distortion_scale;
uniform float intensity;
uniform float speed;

uniform vec4 water_color : source_color;/* = vec4(2.0);

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	float distortion = texture(noise, UV*scale*distortion_scale + TIME * speed).x;
	distortion -= 0.5;
	float uv_height = SCREEN_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.y;
	vec2 reflected_screenuv = vec2(SCREEN_UV.x - distortion * intensity * y_zoom, SCREEN_UV.y + uv_height * UV.y * scale.y * 2.0);
	
	vec4 reflection = texture(SCREEN_TEXTURE, reflected_screenuv);
	COLOR.rgb = mix(reflection.rgb, water_color.rgb,water_color.a);
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
*/