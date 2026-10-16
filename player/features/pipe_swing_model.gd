class_name PipeSwingModel
extends RefCounted

## Pure pipe swing physics. No scene, input or Player dependencies.

const RESTORE: float = 5.0
const DAMPING: float = 1.5
const DEFAULT_MAX_ANGLE: float = 0.45
const HOLD_ACCELERATION: float = 4.6
const EDGE_RETURN_VELOCITY: float = 0.7
const OUTWARD_SPEED_AT_EDGE: float = 0.12
const PROGRESSIVE_SECOND_ANGLE: float = 0.73
const PROGRESSIVE_THIRD_ANGLE: float = 1.2
const FIRST_SPEED_SCALE: float = 0.65
const SECOND_SPEED_SCALE: float = 0.85

var angle: float = 0.0
var velocity: float = 0.0
var max_angle: float = DEFAULT_MAX_ANGLE
var reversal_count: int = 0
var last_input_direction: float = 0.0
var input_locked: bool = false
var locked_direction: float = 0.0

func reset(initial_angle: float = 0.0, initial_velocity: float = 0.0) -> void:
	angle = initial_angle
	velocity = initial_velocity
	max_angle = DEFAULT_MAX_ANGLE
	reversal_count = 0
	last_input_direction = 0.0
	input_locked = false
	locked_direction = 0.0

func step(delta: float, horizontal_input: float) -> float:
	if not is_zero_approx(horizontal_input):
		var input_direction: float = signf(horizontal_input)
		if not is_zero_approx(last_input_direction) and input_direction != last_input_direction:
			reversal_count += 1
			if reversal_count >= 4:
				max_angle = PROGRESSIVE_THIRD_ANGLE
			elif reversal_count >= 2:
				max_angle = PROGRESSIVE_SECOND_ANGLE
		last_input_direction = input_direction

	if is_zero_approx(horizontal_input):
		input_locked = false
		locked_direction = 0.0
	elif input_locked and signf(horizontal_input) == locked_direction:
		pass
	else:
		var reached_same_side: bool = absf(angle) >= max_angle - 0.02 and signf(angle) == signf(horizontal_input)
		if reached_same_side:
			velocity = -signf(angle) * EDGE_RETURN_VELOCITY
			input_locked = true
			locked_direction = signf(horizontal_input)
		else:
			var speed_scale: float = 1.0
			if reversal_count < 2:
				speed_scale = FIRST_SPEED_SCALE
			elif reversal_count < 4:
				speed_scale = SECOND_SPEED_SCALE
			velocity += horizontal_input * HOLD_ACCELERATION * speed_scale * delta

	velocity = move_toward(velocity, 0.0, DAMPING * delta)
	velocity -= angle * RESTORE * delta
	velocity = clampf(velocity, -2.8, 2.8)
	var angle_ratio: float = clampf(absf(angle) / max_angle, 0.0, 1.0)
	var is_moving_outward: bool = absf(angle) > 0.01 and signf(velocity) == signf(angle)
	if is_moving_outward:
		var outward_speed_limit: float = lerpf(2.8, OUTWARD_SPEED_AT_EDGE, angle_ratio * angle_ratio)
		velocity = clampf(velocity, -outward_speed_limit, outward_speed_limit)
	angle = clampf(angle + velocity * delta, -max_angle, max_angle)
	var world_direction: float = -velocity
	if absf(world_direction) < 0.20:
		world_direction = -angle
	return world_direction
