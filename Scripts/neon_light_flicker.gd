extends PointLight2D

## Light timing for the animated neon sign.
## Frame brightness is measured from the actual textures, so the light stays
## synchronized when the SpriteFrames animation is edited or reordered.
@export var base_energy: float = 4.08
@export var response_speed: float = 80.0

@onready var neon: AnimatedSprite2D = get_parent() as AnimatedSprite2D

var frame_intensities: Array[float] = []


func _ready() -> void:
	energy = 0.0
	_cache_frame_intensities()


func _process(delta: float) -> void:
	if not is_instance_valid(neon):
		return

	if frame_intensities.is_empty():
		return

	var frame := clampi(neon.frame, 0, frame_intensities.size() - 1)
	var target_energy: float = base_energy * frame_intensities[frame]

	energy = move_toward(energy, target_energy, response_speed * delta)


func _cache_frame_intensities() -> void:
	var animation_name := neon.animation
	var frame_count := neon.sprite_frames.get_frame_count(animation_name)
	var raw_brightness: Array[float] = []
	var brightest := 0.0

	for frame_index in frame_count:
		var texture := neon.sprite_frames.get_frame_texture(animation_name, frame_index)
		var brightness := _measure_texture_brightness(texture)
		raw_brightness.append(brightness)
		brightest = maxf(brightest, brightness)

	if is_zero_approx(brightest):
		return

	for brightness in raw_brightness:
		# Keep weakly lit frames visible while preserving sharp flicker drops.
		frame_intensities.append(clampf(brightness / brightest, 0.0, 1.0))


func _measure_texture_brightness(texture: Texture2D) -> float:
	if texture == null:
		return 0.0

	var image := texture.get_image()
	if image.is_empty():
		return 0.0

	var sample_step := maxi(1, int(mini(image.get_width(), image.get_height()) / 32.0))
	var brightness_sum := 0.0
	var sample_count := 0

	for y in range(0, image.get_height(), sample_step):
		for x in range(0, image.get_width(), sample_step):
			var pixel := image.get_pixel(x, y)
			brightness_sum += maxf(maxf(pixel.r, pixel.g), pixel.b) * pixel.a
			sample_count += 1

	return brightness_sum / float(maxi(1, sample_count))
