extends Node2D

var player_old_pos
var player_new_pos
var player_run_speed

@export var NOISE_SHAKE_SPEED: float = 18.0
@export var NOISE_SHAKE_STRENGTH: float = 8.0
@export var SHAKE_DECAY_RATE: float = 8.0
@export var SHOT_SHAKE_STRENGTH: float = 4.0
@export var SHOT_SHAKE_DURATION: float = 0.08
@export var WALK_SWAY_START_SPEED: float = 90.0
@export var WALK_SWAY_MAX_SPEED: float = 180.0
@export var WALK_SWAY_STRENGTH: float = 2.2
@export var WALK_SWAY_FREQUENCY: float = 7.0
@export var RUN_ZOOM_FACTOR: float = 0.92
@export var RUN_ZOOM_DELAY: float = 1.0
@export var CROUCH_ZOOM_FACTOR: float = 1.10
@export var CROUCH_ZOOM_DELAY: float = 0.5
@export var ZOOM_TRANSITION_SPEED: float = 0.6
@export var CROUCH_ZOOM_TRANSITION_SPEED: float = 0.18

@onready var camera: Camera2D = $"../Camera2D"
@onready var rand := RandomNumberGenerator.new()

var noise := FastNoiseLite.new()
var noise_i := 0.0
var shake_strength := 0.0
var shot_shake_time := 0.0
var camera_base_offset := Vector2.ZERO
var camera_base_zoom := Vector2.ONE
var walk_sway_strength := 0.0
var walk_sway_phase := 0.0
var crouch_zoom_elapsed := 0.0
var run_zoom_elapsed := 0.0


func _ready() -> void:
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	rand.randomize()
	noise.seed = rand.randi()
	noise.frequency = 20.0
	camera_base_offset = camera.offset
	camera_base_zoom = camera.zoom
	Signals.connect("player_position_update", Callable(self, "_on_player_position_update"))
	Signals.connect("player_run_speed_update", Callable(self, "_on_player_run_speed_update"))


func _on_player_position_update(player_pos) -> void:
	player_new_pos = player_pos


func _on_player_run_speed_update(run_speed) -> void:
	player_run_speed = run_speed


func apply_noise_shake() -> void:
	shake_strength = lerpf(shake_strength, NOISE_SHAKE_STRENGTH, 0.35)


func apply_shot_shake() -> void:
	shot_shake_time = SHOT_SHAKE_DURATION


func _process(delta: float) -> void:
	var player_body := get_parent() as CharacterBody2D
	var horizontal_speed: float = absf(player_body.velocity.x) if is_instance_valid(player_body) else 0.0
	var is_running: bool = is_instance_valid(player_body) and player_body.get("RUN_SPEED") == 2 and horizontal_speed > 0.0
	# Player state enum: IN_AIR=0, ON_FLOOR=1, SITDOWN=2.
	var is_crouching: bool = is_instance_valid(player_body) and player_body.get("state") == 2
	if is_running:
		run_zoom_elapsed += delta
	else:
		run_zoom_elapsed = 0.0
	if is_crouching:
		crouch_zoom_elapsed += delta
	else:
		crouch_zoom_elapsed = 0.0
	var target_zoom := camera_base_zoom
	if is_running and run_zoom_elapsed >= RUN_ZOOM_DELAY:
		target_zoom = camera_base_zoom * RUN_ZOOM_FACTOR
	elif crouch_zoom_elapsed >= CROUCH_ZOOM_DELAY:
		target_zoom = camera_base_zoom * CROUCH_ZOOM_FACTOR
	var zoom_transition_speed: float = CROUCH_ZOOM_TRANSITION_SPEED if is_crouching else ZOOM_TRANSITION_SPEED
	var zoom_blend: float = 1.0 - exp(-zoom_transition_speed * delta)
	camera.zoom = camera.zoom.lerp(target_zoom, zoom_blend)
	var speed_ratio: float = inverse_lerp(WALK_SWAY_START_SPEED, WALK_SWAY_MAX_SPEED, horizontal_speed)
	var target_sway_strength: float = clampf(speed_ratio, 0.0, 1.0) if horizontal_speed > WALK_SWAY_START_SPEED else 0.0
	var sway_blend: float = 1.0 - exp(-8.0 * delta)
	walk_sway_strength = lerpf(walk_sway_strength, target_sway_strength, sway_blend)
	if walk_sway_strength > 0.001:
		walk_sway_phase += delta * lerpf(WALK_SWAY_FREQUENCY, WALK_SWAY_FREQUENCY * 1.25, target_sway_strength)

	shake_strength = lerpf(shake_strength, 0.0, SHAKE_DECAY_RATE * delta)
	shot_shake_time = maxf(0.0, shot_shake_time - delta)
	var shot_strength := SHOT_SHAKE_STRENGTH * clampf(shot_shake_time / SHOT_SHAKE_DURATION, 0.0, 1.0)
	var sway_offset := Vector2(
		sin(walk_sway_phase) * WALK_SWAY_STRENGTH * walk_sway_strength,
		sin(walk_sway_phase * 2.0) * WALK_SWAY_STRENGTH * 0.35 * walk_sway_strength
	)
	var shake_offset := get_noise_offset(delta, maxf(shake_strength, shot_strength)) if maxf(shake_strength, shot_strength) > 0.01 else Vector2.ZERO
	camera.offset = camera_base_offset + sway_offset + shake_offset


func get_noise_offset(delta: float, strength: float) -> Vector2:
	noise_i += delta * NOISE_SHAKE_SPEED
	return Vector2(
		noise.get_noise_2d(1, noise_i) * strength,
		noise.get_noise_2d(100, noise_i) * strength
	)
