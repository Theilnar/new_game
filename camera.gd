extends Node2D

var player_old_pos
var player_new_pos
var player_run_speed
# How quickly to move through the noise
@export var NOISE_SHAKE_SPEED: float = 0.0
# Noise returns values in the range (-1, 1)
# So this is how much to multiply the returned value by
@export var NOISE_SHAKE_STRENGTH: float = 8.0#8.0
# Multiplier for lerping the shake strength to zero
@export var SHAKE_DECAY_RATE: float = 0.0

@onready var camera = $"../Camera2D"
@onready var rand = RandomNumberGenerator.new()

var noise = FastNoiseLite.new()
@onready var apply_button = $Sprite2D

# Used to keep track of where we are in the noise
# so that we can smoothly move through it
var noise_i: float = 0.0

var shake_strength: float = 0.0

func _ready() -> void:
	
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	rand.randomize()
	# Randomize the generated noise
	noise.seed = rand.randi()
	# Period affects how quickly the noise changes values
	noise.frequency = 20
	
	#apply_button.connect("pressed", self, "apply_shake")
	Signals.connect("player_position_update", Callable (self, "_on_player_position_update"))
	Signals.connect("player_run_speed_update", Callable (self, "_on_player_run_speed_update"))
	#Signals.connect("player_attack", Callable (self, "_on_damage_received"))
	
func _on_player_position_update(player_pos):
	player_new_pos = player_pos
	
	
func _on_player_run_speed_update(run_speed):
	player_run_speed = run_speed
	#print(player_run_speed)


func apply_noise_shake() -> void:
	shake_strength = NOISE_SHAKE_STRENGTH

func _process(delta: float) -> void:
	#if Input.is_action_just_pressed("block"):
	
	if player_run_speed == 2:
		noise.frequency = 60
		#print(noise.frequency)
	elif player_run_speed == 1:
		noise.frequency = 15
		#print(noise.frequency)
		
	if player_old_pos != player_new_pos:
		#print(player_old_pos, ' ', player_new_pos)
		player_old_pos = player_new_pos
		#print(player_old_pos, ' ', player_new_pos)
		apply_noise_shake()
	# Fade out the intensity over time
		shake_strength = lerp(shake_strength, 0.0, SHAKE_DECAY_RATE * delta)

	# Shake by adjusting camera.offset so we can move the camera around the level via it's position
		camera.offset = get_noise_offset(delta)

func get_noise_offset(delta: float) -> Vector2:
	noise_i += delta * NOISE_SHAKE_SPEED
	# Set the x values of each call to 'get_noise_2d' to a different value
	# so that our x and y vectors will be reading from unrelated areas of noise
	return Vector2(
		noise.get_noise_2d(1, noise_i) * shake_strength,
		noise.get_noise_2d(100, noise_i) * shake_strength
	)
