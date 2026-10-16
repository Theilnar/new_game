extends CharacterBody2D

enum State {
	WANDER,
	AVOID,
	CHASE,
	STUN,
	DEAD,
	WINDUP,
	DASH
}

@export var max_hp: int = 10
@export var move_speed: float = 90.0
@export var acceleration: float = 280.0
@export var chase_speed: float = 125.0
@export_range(0.0, 0.5, 0.01) var speed_variation: float = 0.12
@export var attack_range: float = 90.0
@export var attack_windup_duration: float = 0.45
@export var attack_dash_speed: float = 420.0
@export var attack_damage: int = 4
@export var attack_cooldown: float = 0.85
@export_range(0.1, 1.0, 0.05) var recovery_speed_multiplier: float = 0.5
@export var attack_animation_duration: float = 0.22
@export var wander_radius: float = 220.0
@export var wander_time_min: float = 0.9
@export var wander_time_max: float = 2.2
@export var detection_radius: float = 260.0
@export var lose_target_radius: float = 360.0
@export var sensor_count: int = 4
@export var sensor_length: float = 72.0
@export var sensor_collision_mask: int = 257
@export var avoidance_strength: float = 1.6
@export var home_pull_strength: float = 0.9
@export var home_return_radius: float = 1.35
@export var bob_amplitude: float = 4.0
@export var bob_speed: float = 6.0
@export var turn_smooth: float = 9.0
@export var max_flight_tilt_degrees: float = 18.0
@export var death_gravity: float = 520.0
@export var death_rotation_degrees: float = 90.0

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var wing_left: Polygon2D = $Visual/WingLeft
@onready var wing_right: Polygon2D = $Visual/WingRight
@onready var body: Polygon2D = $Visual/Body
@onready var head: Polygon2D = $Visual/Head
@onready var state_label: Label = $StateLabel
@onready var sensors_root: Node2D = $Sensors

var state: State = State.WANDER
var hp: int
var home_position: Vector2
var wander_target: Vector2
var wander_timer: float = 0.0
var stun_timer: float = 0.0
var flight_time: float = 0.0
var sensors: Array[RayCast2D] = []
var player_target: CharacterBody2D = null
var attack_cooldown_timer: float = 0.0
var attack_animation_timer: float = 0.0
var facing_direction: int = 1
var death_landed: bool = false
var attack_windup_timer: float = 0.0
var attack_target_position: Vector2
var attack_direction: Vector2 = Vector2.RIGHT
var flight_collision_mask: int

func _ready() -> void:
	randomize()
	_randomize_speeds()
	hp = max_hp
	home_position = global_position
	flight_collision_mask = collision_mask
	_build_sensors()
	_pick_new_wander_target()
	_update_state_label()

func _randomize_speeds() -> void:
	move_speed *= randf_range(1.0 - speed_variation, 1.0 + speed_variation)
	chase_speed *= randf_range(1.0 - speed_variation, 1.0 + speed_variation)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_process_death(delta)
		return

	if state == State.STUN:
		stun_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2.0 * delta)
		move_and_slide()
		_update_visual(delta)
		if stun_timer <= 0.0:
			state = State.WANDER
			_pick_new_wander_target()
		_update_state_label()
		return

	flight_time += delta
	attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)
	attack_animation_timer = maxf(0.0, attack_animation_timer - delta)
	# These states keep the position captured before the pause, never retarget.
	if state == State.WINDUP or state == State.DASH:
		if state == State.WINDUP:
			_process_windup(delta)
		else:
			_process_dash(delta)
		_update_visual(delta)
		_update_state_label()
		return
	_update_player_target()
	_try_attack()
	if state == State.WINDUP:
		_update_visual(delta)
		_update_state_label()
		return

	if state != State.CHASE:
		wander_timer -= delta
	if state != State.CHASE and (wander_timer <= 0.0 or global_position.distance_to(wander_target) < 24.0):
		_pick_new_wander_target()

	var desired_direction := _get_desired_direction()
	var avoidance_direction := _get_avoidance_direction()
	var steering := desired_direction + avoidance_direction * avoidance_strength

	if state != State.CHASE and avoidance_direction.length() > 0.15:
		state = State.AVOID
	elif state == State.AVOID:
		state = State.WANDER

	if state != State.CHASE and steering.length() < 0.05:
		steering = Vector2.RIGHT.rotated(randf_range(0.0, TAU))

	steering = steering.normalized()
	var target_speed := chase_speed if state == State.CHASE else move_speed
	if state != State.CHASE and attack_cooldown_timer > 0.0:
		target_speed *= recovery_speed_multiplier
	velocity = velocity.move_toward(steering * target_speed, acceleration * delta)

	if state != State.CHASE and global_position.distance_to(home_position) > wander_radius * home_return_radius:
		velocity = velocity.move_toward((home_position - global_position).normalized() * target_speed, acceleration * delta)

	move_and_slide()
	_update_visual(delta)
	_update_state_label()

func _process_death(delta: float) -> void:
	_update_sprite_animation()
	if not death_landed:
		velocity.y += death_gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		move_and_slide()
		if is_on_floor():
			death_landed = true
			velocity = Vector2.ZERO

	visual.position.y = 0.0
	var death_rotation := deg_to_rad(death_rotation_degrees) * facing_direction
	visual.rotation = lerp_angle(visual.rotation, death_rotation, turn_smooth * delta)
	visual.scale.x = abs(visual.scale.x) * facing_direction

func _has_live_target() -> bool:
	return is_instance_valid(player_target) and not player_target.is_queued_for_deletion() and player_target.get("is_dead") != true

func _build_sensors() -> void:
	for child in sensors_root.get_children():
		child.queue_free()
	sensors.clear()

	for i in range(sensor_count):
		var ray := RayCast2D.new()
		ray.name = "Ray%02d" % i
		ray.enabled = true
		ray.collide_with_areas = false
		ray.collide_with_bodies = true
		ray.collision_mask = sensor_collision_mask
		var angle := (TAU / float(sensor_count)) * float(i)
		ray.target_position = Vector2.RIGHT.rotated(angle) * sensor_length
		sensors_root.add_child(ray)
		sensors.append(ray)

func _pick_new_wander_target() -> void:
	wander_timer = randf_range(wander_time_min, wander_time_max)
	var offset := Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
	if offset.length() > wander_radius:
		offset = offset.normalized() * randf_range(wander_radius * 0.45, wander_radius)
	wander_target = home_position + offset

func _update_player_target() -> void:
	# After each attempt, fly freely before looking for the player again.
	if attack_cooldown_timer > 0.0:
		return
	if _has_live_target():
		if global_position.distance_to(player_target.global_position) > lose_target_radius:
			player_target = null
			state = State.WANDER
			_pick_new_wander_target()
		else:
			state = State.CHASE
		return

	player_target = null
	if state == State.CHASE:
		state = State.WANDER
		_pick_new_wander_target()
	var candidate: Node = get_tree().get_first_node_in_group("player")
	if candidate is CharacterBody2D and not candidate.is_queued_for_deletion() and candidate.get("is_dead") != true and global_position.distance_to(candidate.global_position) <= detection_radius:
		player_target = candidate
		state = State.CHASE

func _get_chase_direction() -> Vector2:
	if player_target == null or not is_instance_valid(player_target):
		return Vector2.ZERO
	var to_player := player_target.global_position - global_position
	if to_player.length() <= attack_range:
		return Vector2.ZERO
	if to_player.length() <= 0.001:
		return Vector2.ZERO
	return to_player.normalized()

func _try_attack() -> void:
	if state != State.CHASE or not _has_live_target():
		return
	if attack_cooldown_timer > 0.0:
		return
	if global_position.distance_to(player_target.global_position) > attack_range:
		return

	attack_target_position = player_target.global_position
	attack_direction = global_position.direction_to(attack_target_position)
	if attack_direction.is_zero_approx():
		attack_direction = Vector2(float(facing_direction), 0.0)
	attack_windup_timer = attack_windup_duration
	velocity = Vector2.ZERO
	state = State.WINDUP
	if absf(attack_direction.x) > 0.01:
		facing_direction = 1 if attack_direction.x > 0.0 else -1

func _process_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	if not _has_live_target():
		_finish_attack()
		return
	attack_windup_timer = maxf(0.0, attack_windup_timer - delta)
	if attack_windup_timer <= 0.0:
		state = State.DASH
		# Sweep the body against the player as well as the world during a dash.
		collision_mask = flight_collision_mask | (1 << 1)
		velocity = attack_direction * attack_dash_speed

func _process_dash(delta: float) -> void:
	if not _has_live_target():
		_finish_attack()
		return
	var remaining := global_position.distance_to(attack_target_position)
	velocity = attack_direction * attack_dash_speed
	var motion := attack_direction * minf(attack_dash_speed * delta, remaining)
	# Swept collision prevents fast lunges from tunneling through players/walls.
	var collision := move_and_collide(motion, false, 0.08, true)
	if collision != null:
		var hit_player := collision.get_collider() == player_target
		_finish_attack()
		if hit_player:
			Signals.emit_signal("enemy_attack", attack_damage)
			attack_animation_timer = attack_animation_duration
		return
	if global_position.distance_to(attack_target_position) <= 0.5:
		_finish_attack()

func _cancel_attack() -> void:
	collision_mask = flight_collision_mask
	attack_windup_timer = 0.0
	attack_animation_timer = 0.0
	attack_cooldown_timer = attack_cooldown
	player_target = null

func _finish_attack() -> void:
	_cancel_attack()
	state = State.WANDER
	velocity = Vector2.ZERO
	_pick_new_wander_target()

func _get_desired_direction() -> Vector2:
	if state == State.CHASE:
		return _get_chase_direction()

	var to_target := wander_target - global_position
	if to_target.length() <= 0.001:
		return Vector2.ZERO

	if global_position.distance_to(home_position) > wander_radius:
		return (home_position - global_position).normalized() * home_pull_strength

	return to_target.normalized()

func _get_avoidance_direction() -> Vector2:
	var avoidance := Vector2.ZERO
	for ray in sensors:
		ray.force_raycast_update()
		if not ray.is_colliding():
			continue

		var ray_dir := ray.target_position.normalized()
		var hit_distance := global_position.distance_to(ray.get_collision_point())
		var hit_weight := 1.0 - clampf(hit_distance / sensor_length, 0.0, 1.0)
		avoidance -= ray_dir * (0.35 + hit_weight)

	return avoidance

func _update_visual(delta: float) -> void:
	_update_sprite_animation()
	var flight_animation_speed := bob_speed * (1.35 if state == State.CHASE else 1.0)
	var bob_height := bob_amplitude * (1.2 if state == State.CHASE else 1.0)
	if state == State.WINDUP:
		bob_height *= 0.25
	var bob := sin(flight_time * flight_animation_speed) * bob_height
	visual.position.y = bob

	if velocity.x < -1.0:
		facing_direction = -1
	elif velocity.x > 1.0:
		facing_direction = 1

	var tilt_reference := maxf(abs(velocity.x), move_speed * 0.35)
	var vertical_factor := clampf(velocity.y / tilt_reference, -1.0, 1.0)
	var target_rotation := vertical_factor * deg_to_rad(max_flight_tilt_degrees)
	visual.rotation = lerp_angle(visual.rotation, target_rotation, turn_smooth * delta)

	var flap := sin(flight_time * (flight_animation_speed * 1.75)) * 0.22
	wing_left.rotation = -0.35 + flap
	wing_right.rotation = 0.35 - flap
	wing_left.scale = Vector2(1.0, 1.0 + abs(flap) * 0.15)
	wing_right.scale = Vector2(1.0, 1.0 + abs(flap) * 0.15)

	visual.scale.x = abs(visual.scale.x) * facing_direction

	if state == State.WINDUP:
		visual.scale.y = 0.94
		visual.modulate = Color(1.0, 0.8, 0.65)
	elif attack_animation_timer > 0.0:
		var attack_progress := attack_animation_timer / attack_animation_duration
		visual.scale.y = 1.0 + sin((1.0 - attack_progress) * PI) * 0.18
		visual.modulate = Color(1.0, 0.55 + attack_progress * 0.45, 0.55 + attack_progress * 0.45)
	else:
		visual.scale.y = 1.0
		visual.modulate = Color.WHITE

func _update_sprite_animation() -> void:
	if sprite == null:
		return
	if state == State.WINDUP:
		if sprite.animation != &"attack":
			sprite.play(&"attack")
		sprite.pause()
		sprite.frame = 0
		return

	var animation_name: StringName = &"fly"
	if state == State.DEAD:
		animation_name = &"death"
	elif state == State.STUN:
		animation_name = &"hurt"
	elif state == State.DASH:
		animation_name = &"attack"
	elif state == State.CHASE:
		animation_name = &"fast_flight"

	if sprite.animation != animation_name or (state == State.DASH and not sprite.is_playing()):
		sprite.play(animation_name)

func _update_state_label() -> void:
	if state_label == null:
		return
	state_label.text = _state_name(state)

func _state_name(value: State) -> String:
	match value:
		State.WANDER:
			return "WANDER"
		State.AVOID:
			return "AVOID"
		State.CHASE:
			return "CHASE"
		State.STUN:
			return "STUN"
		State.DEAD:
			return "DEAD"
		State.WINDUP:
			return "WINDUP"
		State.DASH:
			return "DASH"
		_:
			return "?"

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return

	hp -= amount
	if hp <= 0:
		_die()
		return

	_cancel_attack()
	velocity = knockback_dir * 180.0
	state = State.STUN
	stun_timer = 0.25

func _die() -> void:
	_cancel_attack()
	state = State.DEAD
	death_landed = false
	velocity = Vector2(randf_range(-35.0, 35.0), -90.0)
	attack_animation_timer = 0.0
	_update_state_label()
