extends CharacterBody2D

enum State {
	IDLE,
	SIT,
	PATROL,
	ALERT,
	CHASE,
	POUNCE,
	BITE,
	RETREAT,
	SEARCH,
	HITSTUN,
	DEATH
}

enum PatrolAction {
	WALK,
	WAIT,
	LOOK
}

var player: CharacterBody2D = null

@export var max_hp: int = 25
@export var patrol_speed: float = 35.0
@export var chase_speed: float = 240.0
@export var pounce_speed: float = 140.0
@export var pounce_attack_speed: float = 230.0
@export var retreat_speed: float = 50.0
@export var gravity: float = 1200.0
@export var jump_velocity: float = -320.0

@export var attack_range: float = 28.0
@export var pounce_range: float = 90.0
@export var pounce_min_distance: float = 60.0
@export var pounce_max_distance: float = 150.0
@export var pounce_windup_time: float = 0.08
@export var pounce_active_time: float = 0.16
@export var pounce_recovery_time: float = 0.25
@export var jump_cooldown_time: float = 0.45
@export var attack_offset_x: float = 34.0
@export var attack_offset_y: float = -16.0
@export var detection_lost_time: float = 2.5
@export var alert_delay: float = 1.45
@export var bite_damage: int = 6
@export var bite_windup_time: float = 0.10
@export var bite_active_time: float = 0.15
@export var bite_recovery_time: float = 0.35
@export var retreat_time_min: float = 0.20
@export var retreat_time_max: float = 0.45
@export var retreat_speed_multiplier: float = 1.25
@export var pounce_damage: int = 9
@export var hitstun_time: float = 0.25
@export var wall_turn_lock_time: float = 0.2
@export var idle_time_min: float = 1.6
@export var idle_time_max: float = 4.8
@export var sit_time_min: float = 1.0
@export var sit_time_max: float = 3.0
@export var sit_chance: float = 0.25
@export var patrol_walk_time_min: float = 0.8
@export var patrol_walk_time_max: float = 2.6
@export var patrol_wait_time_min: float = 0.4
@export var patrol_wait_time_max: float = 1.4
@export var patrol_look_time_min: float = 0.5
@export var patrol_look_time_max: float = 1.2
@export var patrol_speed_jitter: float = 0.35
@export var sniff_chance: float = 0.35
@export var enable_combat_ai: bool = true
@export var detection_offset_x: float = 200.0
@export var detection_offset_y: float = -24.0
@export var vision_ray_length: float = 470.0
@export var vision_ray_y: float = 0.0
@export var vision_ray_high_y: float = -25.0
@export var vision_ray_top_y: float = -110.0
@export var vision_ray_low_y: float = 32.0
@export var vision_lost_grace_time: float = 0.35
@export var walk_sfx: AudioStream
@export var run_sfx: AudioStream
@export var run_sfx_variants: Array[AudioStream] = []
@export var sniff_sfx: AudioStream
@export var bark_sfx: AudioStream
@export var bite_sfx: AudioStream

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_label: Label = $StateLabel
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_polygon: CollisionPolygon2D = $DetectionArea/CollisionPolygon2D
@onready var vision_ray: RayCast2D = $VisionRay
@onready var vision_ray_high: RayCast2D = $VisionRayHigh
@onready var vision_ray_top: RayCast2D = $VisionRayTop
@onready var vision_ray_low: RayCast2D = $VisionRayLow
@onready var sfx_walk: AudioStreamPlayer2D = $SFXWalk
@onready var sfx_run: AudioStreamPlayer2D = $SFXRun
@onready var sfx_sniff: AudioStreamPlayer2D = $SFXSniff
@onready var sfx_bark: AudioStreamPlayer2D = $SFXBark
@onready var sfx_bite: AudioStreamPlayer2D = $SFXBite
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var ground_check: RayCast2D = $GroundCheck
@onready var wall_check_front: RayCast2D = $WallCheckFront
@onready var wall_check_back: RayCast2D = $WallCheckBack
@onready var ledge_check: RayCast2D = $LedgeCheck
@onready var alert_timer: Timer = $Timers/AlertTimer
@onready var attack_cooldown: Timer = $Timers/AttackCooldown
@onready var search_timer: Timer = $Timers/SearchTimer

var state: State = State.IDLE
var hp: int
var facing_dir: int = 1


var last_known_player_pos: Vector2
var can_see_player: bool = false
var attack_active: bool = false
var has_hit_this_attack: bool = false
var search_pos: Vector2
var wall_turn_lock: float = 0.0
var state_timer: float = 0.0
var bite_active_timer: float = 0.0
var bite_recovery_timer: float = 0.0
var retreat_timer: float = 0.0
var retreat_dir: int = -1
var pounce_active_timer: float = 0.0
var pounce_recovery_timer: float = 0.0
var pounce_dir: int = 1
var pounce_mode_attack: bool = false
var jump_cooldown_timer: float = 0.0
var patrol_action: PatrolAction = PatrolAction.WALK
var patrol_action_timer: float = 0.0
var patrol_action_duration: float = 0.0
var patrol_look_switched: bool = false
var patrol_move_dir: int = 1
var patrol_walk_speed: float = 0.0
var last_run_sfx_index: int = -1
var vision_lost_timer: float = 0.0

func _ready() -> void:
	randomize()
	hp = max_hp
	vision_ray.collision_mask = (1 << 0) | (1 << 1)
	vision_ray.collide_with_areas = false
	vision_ray.collide_with_bodies = true
	vision_ray_high.collision_mask = (1 << 0) | (1 << 1)
	vision_ray_high.collide_with_areas = false
	vision_ray_high.collide_with_bodies = true
	vision_ray_low.collision_mask = (1 << 0) | (1 << 1)
	vision_ray_low.collide_with_areas = false
	vision_ray_low.collide_with_bodies = true
	attack_area.collision_mask = (1 << 1)
	attack_area.monitoring = false
	alert_timer.one_shot = true
	search_timer.one_shot = true
	attack_cooldown.one_shot = true
	_apply_audio_streams()
	_setup_connections()
	_set_state(State.IDLE)

func _setup_connections() -> void:
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	sfx_run.finished.connect(_on_run_sfx_finished)
	alert_timer.timeout.connect(_on_alert_timer_timeout)
	attack_cooldown.timeout.connect(_on_attack_cooldown_timeout)
	search_timer.timeout.connect(_on_search_timer_timeout)

func _physics_process(delta: float) -> void:
	if state != State.DEATH:
		velocity.y += gravity * delta
		if wall_turn_lock > 0.0:
			wall_turn_lock = maxf(0.0, wall_turn_lock - delta)
		if vision_lost_timer > 0.0:
			vision_lost_timer = maxf(0.0, vision_lost_timer - delta)
		if jump_cooldown_timer > 0.0:
			jump_cooldown_timer = maxf(0.0, jump_cooldown_timer - delta)

	_update_sensors()
	_update_wall_checks()

	match state:
		State.IDLE:
			_state_idle(delta)
		State.SIT:
			_state_sit(delta)
		State.PATROL:
			_state_patrol(delta)
		State.ALERT:
			_state_alert(delta)
		State.CHASE:
			_state_chase(delta)
		State.RETREAT:
			_state_retreat(delta)
		State.POUNCE:
			_state_pounce(delta)
		State.BITE:
			_state_bite(delta)
		State.SEARCH:
			_state_search(delta)
		State.HITSTUN:
			_state_hitstun(delta)
		State.DEATH:
			_state_death(delta)

	_update_facing()
	move_and_slide()

func _set_state(new_state: State) -> void:
	if state == new_state:
		return

	_exit_state(state)
	state = new_state
	_enter_state(state)

func _enter_state(s: State) -> void:
	_update_state_label()
	match s:
		State.IDLE:
			velocity.x = 0
			state_timer = randf_range(idle_time_min, idle_time_max)
			_play("idle")
			_play_sfx(sniff_sfx, sfx_sniff)
		State.SIT:
			velocity.x = 0
			state_timer = randf_range(sit_time_min, sit_time_max)
			_play("sit")
			_play_sfx(sniff_sfx, sfx_sniff)
		State.PATROL:
			_start_patrol_action()
		State.ALERT:
			velocity.x = 0
			_play("alert")
			_play_sfx(bark_sfx, sfx_bark)
			alert_timer.start(alert_delay)
		State.CHASE:
			_play("run")
			_start_run_sfx_loop()
		State.POUNCE:
			velocity.x = 0
			has_hit_this_attack = false
			attack_active = false
			attack_area.set_deferred("monitoring", false)
			pounce_active_timer = pounce_windup_time
			pounce_recovery_timer = pounce_windup_time + pounce_active_time
			if player != null:
				var target_dir: int = int(sign(player.global_position.x - global_position.x))
				if target_dir != 0:
					pounce_dir = target_dir
				else:
					pounce_dir = facing_dir
			else:
				pounce_dir = facing_dir
			velocity.y = jump_velocity
			velocity.x = float(pounce_dir) * (pounce_attack_speed if pounce_mode_attack else pounce_speed)
			_play("run")
			_start_run_sfx_loop()
		State.BITE:
			velocity.x = 0
			has_hit_this_attack = false
			attack_active = false
			attack_area.set_deferred("monitoring", false)
			bite_active_timer = bite_windup_time
			bite_recovery_timer = bite_windup_time + bite_active_time
			_play("bite")
			_play_sfx(bite_sfx, sfx_bite)
		State.RETREAT:
			velocity.x = 0
			retreat_timer = randf_range(retreat_time_min, retreat_time_max)
			retreat_dir = -facing_dir
			_play("run")
			_start_run_sfx_loop()
		State.SEARCH:
			velocity.x = 0
			search_pos = last_known_player_pos
			search_timer.start(detection_lost_time)
			_play("search_sniff")
			_play_sfx(sniff_sfx, sfx_sniff)
		State.HITSTUN:
			_play("hit")
			velocity.x = -facing_dir * retreat_speed
		State.DEATH:
			velocity = Vector2.ZERO
			attack_active = false
			detection_area.monitoring = false
			attack_area.monitoring = false
			hurtbox.monitoring = false
			_play("death")

func _exit_state(s: State) -> void:
	match s:
		State.BITE:
			attack_active = false
			attack_area.set_deferred("monitoring", false)
		State.RETREAT:
			attack_active = false
			attack_area.set_deferred("monitoring", false)
		State.CHASE:
			_stop_run_sfx()
		State.POUNCE:
			attack_active = false
			attack_area.set_deferred("monitoring", false)
			_stop_run_sfx()

func _state_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 250.0 * delta)
	state_timer -= delta

	if _has_target():
		_set_state(State.ALERT)
		return

	if state_timer <= 0.0:
		if randf() < sniff_chance:
			_play("sniff")
			state_timer = randf_range(idle_time_min, idle_time_max)
		elif randf() < sit_chance:
			_set_state(State.SIT)
		else:
			_set_state(State.PATROL)

func _state_sit(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 250.0 * delta)
	state_timer -= delta

	if _has_target():
		_set_state(State.ALERT)
		return

	if state_timer <= 0.0:
		if randf() < sniff_chance:
			_play("sniff")
			state_timer = randf_range(sit_time_min, sit_time_max)
		else:
			_set_state(State.PATROL)

func _state_patrol(delta: float) -> void:
	if _has_target():
		_set_state(State.ALERT)
		return

	patrol_action_timer -= delta

	match patrol_action:
		PatrolAction.WALK:
			if _should_turn_around():
				_turn_around()
				patrol_move_dir = facing_dir

			velocity.x = patrol_walk_speed * float(patrol_move_dir)
			if patrol_action_timer <= 0.0:
				_choose_next_patrol_action()
		PatrolAction.WAIT:
			velocity.x = move_toward(velocity.x, 0, 240.0 * delta)
			if patrol_action_timer <= 0.0:
				_choose_next_patrol_action()
		PatrolAction.LOOK:
			velocity.x = move_toward(velocity.x, 0, 240.0 * delta)
			if not patrol_look_switched and patrol_action_timer <= (0.5 * patrol_action_duration):
				facing_dir *= -1
				patrol_look_switched = true
				_scale_sprite()
			if patrol_action_timer <= 0.0:
				_choose_next_patrol_action()

func _state_alert(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 300.0 * delta)

	if player != null:
		var d: float = global_position.distance_to(player.global_position)
		if d <= attack_range:
			_set_state(State.CHASE)
			return

func _state_chase(delta: float) -> void:
	if not _has_target():
		_set_state(State.SEARCH)
		return

	var target_x: float = player.global_position.x
	var target_dir: int = int(sign(target_x - global_position.x))
	if target_dir != 0 and wall_turn_lock <= 0.0:
		facing_dir = target_dir

	var dist: float = global_position.distance_to(player.global_position)

	if dist <= attack_range and attack_cooldown.is_stopped():
		_set_state(State.BITE)
		return

	if jump_cooldown_timer <= 0.0 and _should_pounce_obstacle():
		pounce_mode_attack = false
		_set_state(State.POUNCE)
		return

	if jump_cooldown_timer <= 0.0 and _should_pounce_attack(dist):
		pounce_mode_attack = true
		_set_state(State.POUNCE)
		return

	if _has_wall_ahead() and wall_turn_lock <= 0.0:
		_turn_around()

	velocity.x = float(facing_dir) * chase_speed

func _state_pounce(delta: float) -> void:
	if not _has_target():
		_set_state(State.SEARCH)
		return

	velocity.x = float(pounce_dir) * (pounce_attack_speed if pounce_mode_attack else pounce_speed)
	pounce_active_timer -= delta
	pounce_recovery_timer -= delta

	if pounce_active_timer <= 0.0 and not attack_active:
		attack_active = true
		attack_area.set_deferred("monitoring", true)

	if pounce_recovery_timer <= 0.0:
		attack_active = false
		attack_area.set_deferred("monitoring", false)
		jump_cooldown_timer = jump_cooldown_time
		if pounce_mode_attack:
			_set_state(State.RETREAT)
		elif _has_target():
			_set_state(State.CHASE)
		else:
			_set_state(State.SEARCH)

	if _has_wall_ahead() and is_on_floor():
		# Если уткнулся в препятствие, всё равно можно продолжить как обычный бег после прыжка
		jump_cooldown_timer = jump_cooldown_time
		pounce_mode_attack = false

func _state_retreat(delta: float) -> void:
	velocity.x = float(retreat_dir) * chase_speed * retreat_speed_multiplier
	retreat_timer -= delta

	if retreat_timer <= 0.0:
		if player != null:
			var target_dir: int = int(sign(player.global_position.x - global_position.x))
			if target_dir != 0:
				facing_dir = target_dir
				_scale_sprite()
				_update_sensors()
			_set_state(State.CHASE)
		else:
			_set_state(State.SEARCH)

func _state_bite(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 500.0 * delta)

	bite_active_timer -= delta
	bite_recovery_timer -= delta

	if bite_active_timer <= 0.0 and not attack_active:
		attack_active = true
		attack_area.set_deferred("monitoring", true)

	if bite_recovery_timer <= 0.0:
		attack_active = false
		attack_area.set_deferred("monitoring", false)
		attack_cooldown.start(bite_recovery_time)
		_set_state(State.RETREAT)

func _state_search(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 350.0 * delta)

	if _has_target():
		_set_state(State.ALERT)
		return

	# Идем к последней точке, если нужно
	var dx: float = search_pos.x - global_position.x
	if abs(dx) > 8.0:
		if wall_turn_lock <= 0.0:
			facing_dir = int(sign(dx))
		velocity.x = float(facing_dir) * (patrol_speed * 0.8)
	else:
		velocity.x = 0

func _state_hitstun(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 600.0 * delta)

func _state_death(delta: float) -> void:
	velocity.x = 0

func _has_target() -> bool:
	return player != null and can_see_player

func _should_pounce_obstacle() -> bool:
	if not is_on_floor():
		return false
	if jump_cooldown_timer > 0.0:
		return false
	return _has_wall_ahead()

func _should_pounce_attack(dist: float) -> bool:
	if not is_on_floor():
		return false
	if jump_cooldown_timer > 0.0:
		return false
	if dist < pounce_min_distance or dist > pounce_max_distance:
		return false
	return true

func _update_sensors() -> void:
	_update_detection_area()
	_update_attack_area()
	_update_vision_rays()
	_update_visibility()

func _update_detection_area() -> void:
	detection_area.position = Vector2(detection_offset_x * float(facing_dir), detection_offset_y)
	detection_area.scale = Vector2(float(facing_dir), 1.0)
	if detection_polygon != null:
		detection_polygon.scale = Vector2.ONE

func _update_attack_area() -> void:
	if attack_shape == null:
		return
	attack_shape.position = Vector2(attack_offset_x * float(facing_dir), attack_offset_y)

func _update_vision_rays() -> void:
	vision_ray.target_position = Vector2(vision_ray_length * float(facing_dir), vision_ray_y)
	vision_ray.enabled = true
	vision_ray.force_raycast_update()
	vision_ray_high.target_position = Vector2(vision_ray_length * float(facing_dir), vision_ray_high_y)
	vision_ray_high.enabled = true
	vision_ray_high.force_raycast_update()
	vision_ray_top.target_position = Vector2(vision_ray_length * float(facing_dir), vision_ray_top_y)
	vision_ray_top.enabled = true
	vision_ray_top.force_raycast_update()
	vision_ray_low.target_position = Vector2(vision_ray_length * float(facing_dir), vision_ray_low_y)
	vision_ray_low.enabled = true
	vision_ray_low.force_raycast_update()

func _update_visibility() -> void:
	if player == null:
		can_see_player = false
		return

	if not detection_area.overlaps_body(player):
		if vision_lost_timer <= 0.0:
			can_see_player = false
		return

	if _ray_sees_player(vision_ray) or _ray_sees_player(vision_ray_high) or _ray_sees_player(vision_ray_top) or _ray_sees_player(vision_ray_low):
		can_see_player = true
		vision_lost_timer = vision_lost_grace_time
		return

	if vision_lost_timer <= 0.0:
		can_see_player = false

func _ray_sees_player(ray: RayCast2D) -> bool:
	return ray.is_colliding() and ray.get_collider() == player

func _should_turn_around() -> bool:
	if wall_turn_lock > 0.0:
		return false
	if _has_wall_ahead():
		return true
	if not _has_floor_ahead():
		return true
	return false

func _has_wall_ahead() -> bool:
	if wall_check_front.is_colliding():
		return true
	return false

func _has_floor_ahead() -> bool:
	return ground_check.is_colliding() and ledge_check.is_colliding()

func _turn_around() -> void:
	facing_dir *= -1
	wall_turn_lock = wall_turn_lock_time
	_scale_sprite()
	_update_sensors()

func _start_patrol_action() -> void:
	_choose_next_patrol_action(true)

func _choose_next_patrol_action(force_first_walk: bool = false) -> void:
	patrol_look_switched = false

	if force_first_walk:
		patrol_action = PatrolAction.WALK
	else:
		var roll: float = randf()
		if roll < 0.48:
			patrol_action = PatrolAction.WALK
		elif roll < 0.76:
			patrol_action = PatrolAction.WAIT
		else:
			patrol_action = PatrolAction.LOOK

	match patrol_action:
		PatrolAction.WALK:
			patrol_action_duration = randf_range(patrol_walk_time_min, patrol_walk_time_max)
			patrol_action_timer = patrol_action_duration
			patrol_move_dir = facing_dir if facing_dir != 0 else 1
			var jitter: float = randf_range(1.0 - patrol_speed_jitter, 1.0 + patrol_speed_jitter)
			patrol_walk_speed = patrol_speed * jitter
			_play("walk")
			_play_sfx(walk_sfx, sfx_walk)
		PatrolAction.WAIT:
			patrol_action_duration = randf_range(patrol_wait_time_min, patrol_wait_time_max)
			patrol_action_timer = patrol_action_duration
			velocity.x = 0
			_play("idle")
		PatrolAction.LOOK:
			patrol_action_duration = randf_range(patrol_look_time_min, patrol_look_time_max)
			patrol_action_timer = patrol_action_duration
			velocity.x = 0
			if randf() < 0.5:
				facing_dir = -1
			else:
				facing_dir = 1
			_scale_sprite()
			_play("sniff")

func _update_facing() -> void:
	if player != null and state in [State.ALERT, State.CHASE, State.BITE]:
		var dir: int = int(sign(player.global_position.x - global_position.x))
		if dir != 0 and wall_turn_lock <= 0.0:
			facing_dir = dir
			_scale_sprite()
	elif velocity.x != 0 and state != State.IDLE:
		var move_dir: int = int(sign(velocity.x))
		if move_dir != 0:
			facing_dir = move_dir
			_scale_sprite()

func _scale_sprite() -> void:
	animated_sprite.scale.x = abs(animated_sprite.scale.x) * facing_dir

func _update_wall_checks() -> void:
	var front_offset: Vector2 = Vector2(75.0 * float(facing_dir), 1.0)
	var back_offset: Vector2 = Vector2(-97.0 * float(facing_dir), -1.0)
	wall_check_front.target_position = front_offset
	wall_check_back.target_position = back_offset
	ledge_check.target_position = Vector2(28.0 * float(facing_dir), 34.0)
	ground_check.target_position = Vector2(28.0 * float(facing_dir), 34.0)

func _play(anim_name: String) -> void:
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _update_state_label() -> void:
	if state_label == null:
		return
	state_label.text = _state_name(state)

func _state_name(s: State) -> String:
	match s:
		State.IDLE:
			return "IDLE"
		State.SIT:
			return "SIT"
		State.PATROL:
			return "PATROL"
		State.ALERT:
			return "ALERT"
		State.CHASE:
			return "CHASE"
		State.POUNCE:
			return "POUNCE"
		State.BITE:
			return "BITE"
		State.RETREAT:
			return "RETREAT"
		State.SEARCH:
			return "SEARCH"
		State.HITSTUN:
			return "HITSTUN"
		State.DEATH:
			return "DEATH"
		_:
			return "?"

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEATH:
		return

	hp -= amount
	if hp <= 0:
		_set_state(State.DEATH)
		return

	velocity = knockback_dir * 160.0
	_set_state(State.HITSTUN)
	var t := get_tree().create_timer(hitstun_time)
	t.timeout.connect(func():
		if state == State.HITSTUN:
			_set_state(State.RETREAT)
	)

func _on_detection_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body
		can_see_player = true
		last_known_player_pos = player.global_position
		_set_state(State.ALERT)

func _on_detection_body_exited(body: Node) -> void:
	if body == player:
		can_see_player = false
		last_known_player_pos = player.global_position
		search_pos = last_known_player_pos
		_set_state(State.SEARCH)

func _on_attack_area_body_entered(body: Node) -> void:
	if not attack_active:
		return
	if has_hit_this_attack:
		return
	if body.is_in_group("player"):
		has_hit_this_attack = true
		Signals.emit_signal("enemy_attack", bite_damage)
		attack_active = false
		attack_area.set_deferred("monitoring", false)
		call_deferred("_set_state", State.RETREAT)

func _on_attack_cooldown_timeout() -> void:
	if state == State.RETREAT and not attack_active:
		if _has_target():
			_set_state(State.CHASE)
		else:
			_set_state(State.SEARCH)

func _on_animation_finished() -> void:
	match animated_sprite.animation:
		"alert":
			if _has_target():
				_set_state(State.CHASE)
			else:
				_set_state(State.PATROL)
		"bite":
			attack_active = false
			attack_area.set_deferred("monitoring", false)
		"hit":
			if hp > 0:
				_set_state(State.SEARCH)

func _on_alert_timer_timeout() -> void:
	if state == State.ALERT:
		_set_state(State.CHASE)

func _on_search_timer_timeout() -> void:
	if state == State.SEARCH and not _has_target():
		_set_state(State.PATROL)

func _apply_audio_streams() -> void:
	if sfx_walk != null:
		sfx_walk.stream = walk_sfx
	if sfx_run != null:
		sfx_run.stream = run_sfx
	if sfx_sniff != null:
		sfx_sniff.stream = sniff_sfx
	if sfx_bark != null:
		sfx_bark.stream = bark_sfx
	if sfx_bite != null:
		sfx_bite.stream = bite_sfx

func _play_sfx(stream: AudioStream, player: AudioStreamPlayer2D) -> void:
	if player == null:
		return
	if stream == null:
		return
	player.stream = stream
	player.play()

func _start_run_sfx_loop() -> void:
	_play_next_run_sfx(true)

func _stop_run_sfx() -> void:
	if sfx_run != null and sfx_run.playing:
		sfx_run.stop()

func _play_next_run_sfx(avoid_repeat: bool) -> void:
	var chosen: AudioStream = null
	if run_sfx_variants.size() > 0:
		var index: int = randi() % run_sfx_variants.size()
		if avoid_repeat and run_sfx_variants.size() > 1 and index == last_run_sfx_index:
			index = (index + 1) % run_sfx_variants.size()
		last_run_sfx_index = index
		chosen = run_sfx_variants[index]
	else:
		chosen = run_sfx
	_play_sfx(chosen, sfx_run)

func _play_run_sfx() -> void:
	_play_next_run_sfx(true)

func _on_run_sfx_finished() -> void:
	if state == State.CHASE or state == State.RETREAT:
		_play_next_run_sfx(true)
