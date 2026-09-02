shader_type canvas_item;

uniform sampler2D noise_texture: repeat_enable,filter_nearest;

uniform float density: hint_range(0.0, 1.0) = 0.25;

uniform vec2 speed = vec2(0.02, 0.01);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 uv = UV + speed * TIME;
	float noise = texture(noise_texture, uv).r;
	//float fog = clamp(noise * 2.0 - 1.0,0.0,1.0);
	float fog = clamp(noise * 2.0 - 1.0,0.0,1.0);
	COLOR.a = 0.0 + UV.x; /*градиент альфа канала*/
	//COLOR.a = 0.0 + UV.y;
	//COLOR.a = 1.0 - UV.y;

	//vec2 uv1 = -1.0+2.0*UV;
	//float a = 1.0-step(0.3, pow(uv1.x, 5.0)+pow(uv1.y, 4.0));
	//COLOR.a = a;



	COLOR.a *= fog * density;



	// Called for every pixel the material is visible on.
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
