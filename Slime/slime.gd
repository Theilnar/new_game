extends CharacterBody2D

## Small autonomous slime that patrols around its spawn point and occasionally jumps.
@export var patrol_radius: float = 120.0
@export var move_speed: float = 34.0
@export var acceleration: float = 180.0
@export var gravity: float = 1100.0
@export var jump_velocity: float = -300.0
@export_range(0.0, 1.0) var jump_chance: float = 0.28
@export var decision_time_min: float = 0.8
@export var decision_time_max: float = 2.4
@export var idle_time_min: float = 0.35
@export var idle_time_max: float = 1.2

@onready var sprite: Sprite2D = $Sprite2D

var _rng := RandomNumberGenerator.new()
var _start_position := Vector2.ZERO
var _target_x := 0.0
var _decision_timer := 0.0
var _idle_timer := 0.0
var _jump_cooldown := 0.0
var _facing := 1
var _animation_time := 0.0


func _ready() -> void:
	_rng.randomize()
	_start_position = global_position
	_target_x = _start_position.x
	_decision_timer = _rng.randf_range(0.2, 0.8)
	sprite.frame = 0


func _physics_process(delta: float) -> void:
	_animation_time += delta
	_decision_timer = maxf(0.0, _decision_timer - delta)
	_idle_timer = maxf(0.0, _idle_timer - delta)
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if _idle_timer <= 0.0 and (_decision_timer <= 0.0 or absf(global_position.x - _target_x) <= 6.0):
			_choose_next_action()

		if _idle_timer > 0.0:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		else:
			var direction := signf(_target_x - global_position.x)
			velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
			if not is_zero_approx(direction):
				_facing = int(direction)

		if _jump_cooldown <= 0.0 and _rng.randf() < jump_chance * delta:
			velocity.y = jump_velocity
			_jump_cooldown = 1.0

	# Hard clamp keeps accumulated physics drift from taking the slime too far away.
	global_position.x = clampf(
		global_position.x,
		_start_position.x - patrol_radius,
		_start_position.x + patrol_radius
	)
	move_and_slide()
	_update_sprite()


func _choose_next_action() -> void:
	var left_bound := _start_position.x - patrol_radius
	var right_bound := _start_position.x + patrol_radius
	_target_x = _rng.randf_range(left_bound, right_bound)
	_decision_timer = _rng.randf_range(decision_time_min, decision_time_max)
	if _rng.randf() < 0.35:
		_idle_timer = _rng.randf_range(idle_time_min, idle_time_max)


func _update_sprite() -> void:
	sprite.flip_h = _facing < 0
	if not is_on_floor():
		# Green slime jump frames: fourth row of the 10x20 sheet.
		sprite.frame = 30 + (int(_animation_time * 8.0) % 10)
	elif absf(velocity.x) > 4.0:
		# Green slime movement frames: first row of the sheet.
		sprite.frame = int(_animation_time * 8.0) % 10
	else:
		sprite.frame = 0
