extends CharacterBody2D

## Slow zombie: forward vision, hearing, patrol/search, limb damage and crawl mode.

const WANDER_SOUNDS: Array[AudioStream] = [
	preload("res://sound/zombies/zombie-15.wav"), preload("res://sound/zombies/zombie-16.wav"),
	preload("res://sound/zombies/zombie-17.wav"), preload("res://sound/zombies/zombie-18.wav"),
	preload("res://sound/zombies/zombie-19.wav"), preload("res://sound/zombies/zombie-20.wav"),
	preload("res://sound/zombies/zombie-21.wav")
]
const ALERT_SOUNDS: Array[AudioStream] = [
	preload("res://sound/zombies/zombie-8.wav"), preload("res://sound/zombies/zombie-9.wav"),
	preload("res://sound/zombies/zombie-10.wav"), preload("res://sound/zombies/zombie-11.wav"),
	preload("res://sound/zombies/zombie-12.wav")
]
const ATTACK_SOUNDS: Array[AudioStream] = [
	preload("res://sound/zombies/zombie-1.wav"), preload("res://sound/zombies/zombie-2.wav"),
	preload("res://sound/zombies/zombie-3.wav"), preload("res://sound/zombies/zombie-4.wav"),
	preload("res://sound/zombies/zombie-5.wav"), preload("res://sound/zombies/zombie-6.wav"),
	preload("res://sound/zombies/zombie-7.wav")
]
const DAMAGE_SOUNDS: Array[AudioStream] = [
	preload("res://sound/zombies/zombie-22.wav"), preload("res://sound/zombies/zombie-23.wav"),
	preload("res://sound/zombies/zombie-24.wav")
]
const DEATH_SOUND: AudioStream = preload("res://sound/zombies/Undead_Thud.mp3")

enum State { WANDER, INVESTIGATE, ALERT, CHASE, ATTACK_WINDUP, ATTACK, WATCH_HIGH, HIT, DEAD, CRAWL }
enum BodyPart { BODY, HEAD, ARM, LEG }

@export_category("Movement")
@export var walk_speed := 28.0
@export var run_speed := 90.0
@export var crawl_speed := 12.0
@export var acceleration := 180.0
@export var gravity := 980.0
@export var wander_radius := 180.0
@export var wander_pause_min := 0.8
@export var wander_pause_max := 2.8
@export_category("Perception")
@export var vision_distance := 420.0
@export var vision_half_angle := 38.0
@export var vision_up_distance := 140.0
@export var vision_up_horizontal_tolerance := 42.0
@export var hearing_distance := 520.0
@export var memory_time := 3.0
@export var attack_distance := 32.0
@export var upper_target_threshold := 45.0
@export var watch_high_duration := 1.5
@export_category("Damage")
@export var max_health := 100
@export var limb_damage := 20
@export var body_damage_multiplier := 1.0
@export var attack_damage := 8
@export var attack_cooldown := 1.1
@export var hit_recovery_time := 0.7
@export var attack_windup_time := 0.5

@export_category("Zombie Sounds")
## Эти поля можно менять прямо в Inspector перетаскиванием AudioStream-файлов.
@export var wander_sounds: Array[AudioStream] = WANDER_SOUNDS
@export var alert_sounds: Array[AudioStream] = ALERT_SOUNDS
@export var attack_sounds: Array[AudioStream] = ATTACK_SOUNDS
@export var damage_sounds: Array[AudioStream] = DAMAGE_SOUNDS
@export var death_sound: AudioStream = DEATH_SOUND

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $"AttackDirecton_DamageBox_Area2D2#CollisionShape2D"
@onready var vision_ray: RayCast2D = $VisionRay
@onready var vision_ray_high: RayCast2D = $VisionRayHigh
@onready var vision_ray_low: RayCast2D = $VisionRayLow
@onready var vision_ray_up: RayCast2D = $VisionRayUp
@onready var vision_area: Node2D = $VisionArea
@onready var run_area: Area2D = $VisionArea/RunArea
@onready var head_hit_shape: CollisionShape2D = $HeadHitShape
@onready var arm_hit_shape: CollisionShape2D = $ArmHitShape
@onready var leg_hit_shape: CollisionShape2D = $LegHitShape
@onready var attack_direction: Node2D = $AttackDirecton
@onready var head_attack_area: Area2D = $HeadAttackArea
@onready var state_label: Label = get_node_or_null("StateLabel") as Label
var zombie_audio: AudioStreamPlayer2D

var state := State.WANDER
var health: int
var target: Node2D
var last_known_position := Vector2.ZERO
var noise_position := Vector2.ZERO
var memory_left := 0.0
var state_left := 0.0
var attack_left := 0.0
var attack_animation_left := 0.0
var wander_origin := Vector2.ZERO
var facing := 1
var missing_left_arm := false
var missing_right_arm := false
var missing_left_leg := false
var missing_right_leg := false
var arm_hits := 0
var leg_hits := 0
var dead := false
var arm_reaction_left := 0.0
var upward_attack := false
var attack_damage_applied := false
const FACING_DEADZONE := 8.0
var wander_sound_left := 0.0
var alert_sound_left := 0.0
var target_visible_last_frame := false
var lost_target_search_pending := false
var lost_target_search_left := 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("zombies")
	health = max_health
	wander_origin = global_position
	state_left = randf_range(wander_pause_min, wander_pause_max)
	vision_ray.collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3)
	_configure_vision_ray(vision_ray)
	_configure_vision_ray(vision_ray_high)
	_configure_vision_ray(vision_ray_low)
	_configure_vision_ray(vision_ray_up)
	_update_vision_ray_orientation()
	_update_vision_area()
	zombie_audio = AudioStreamPlayer2D.new()
	zombie_audio.name = "ZombieAudio"
	zombie_audio.max_distance = 720.0
	zombie_audio.attenuation = 1.2
	zombie_audio.volume_db = -3.0
	add_child(zombie_audio)
	wander_sound_left = randf_range(2.0, 6.0)
	_play_animation("idle")
	if Signals.has_signal("player_attack") and not Signals.player_attack.is_connected(_on_legacy_damage):
		Signals.player_attack.connect(_on_legacy_damage)

func _physics_process(delta: float) -> void:
	if dead:
		# После смерти зомби не двигается по X, но падает на землю, если был в воздухе.
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0
		_update_state_label()
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	attack_left = maxf(0.0, attack_left - delta)
	memory_left = maxf(0.0, memory_left - delta)
	arm_reaction_left = maxf(0.0, arm_reaction_left - delta)
	target = _find_player()
	var target_visible_now := _can_see_target(target)
	alert_sound_left = maxf(0.0, alert_sound_left - delta)
	if target_visible_now:
		lost_target_search_pending = false
		lost_target_search_left = 0.0
	if target_visible_now and state not in [State.ATTACK_WINDUP, State.ATTACK, State.DEAD] and not _can_melee_target() and not _can_upward_melee_target() and (not target_visible_last_frame or alert_sound_left <= 0.0):
		_play_zombie_sound(alert_sounds)
		alert_sound_left = randf_range(1.4, 3.0)
	target_visible_last_frame = target_visible_now
	var high_target_seen := _can_see_high_target(target)
	if arm_reaction_left > 0.0:
		state = State.HIT
	elif _is_crawler() and state not in [State.ATTACK_WINDUP, State.ATTACK]:
		# Ползание имеет приоритет над обычной погоней: потеряв ноги,
		# зомби больше не должен возвращаться в CHASE/RUN.
		if target_visible_now:
			last_known_position = target.global_position
			memory_left = memory_time
		state = State.CRAWL
	elif state not in [State.ATTACK_WINDUP, State.ATTACK, State.HIT] and attack_left <= 0.0 and _can_upward_melee_target():
		# Ближняя зона над головой работает независимо от VisionRayUp:
		# лестница или край платформы не должны блокировать саму атаку.
		state = State.ATTACK
		velocity.x = 0.0
	elif state not in [State.ATTACK_WINDUP, State.ATTACK, State.HIT] and high_target_seen and absf(target.global_position.x - global_position.x) <= vision_up_horizontal_tolerance:
		# Игрок прямо сверху: держим отдельное состояние, чтобы зомби не
		# переходил между wander/chase и не дёргал зеркальный спрайт.
		state = State.WATCH_HIGH
		last_known_position = target.global_position
		memory_left = memory_time
		state_left = watch_high_duration
	elif state not in [State.ATTACK_WINDUP, State.ATTACK, State.WATCH_HIGH, State.HIT] and _can_see_target(target):
		last_known_position = target.global_position
		memory_left = memory_time
		# Даже если игрок выше, продолжаем идти к нему по горизонтали.
		# WATCH_HIGH используется как визуальная реакция внутри CHASE.
		state = State.CHASE if target.global_position.y < global_position.y - upper_target_threshold else (State.CHASE if global_position.distance_to(target.global_position) > attack_distance else State.ALERT)
	match state:
		State.WANDER: _wander(delta)
		State.INVESTIGATE: _investigate(delta)
		State.ALERT: _alert(delta)
		State.CHASE: _chase(delta)
		State.ATTACK_WINDUP: _attack_windup(delta)
		State.ATTACK: _attack()
		State.WATCH_HIGH: _watch_high(delta)
		State.HIT:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			state_left -= delta
			if state_left <= 0.0:
				state = State.CRAWL if _is_crawler() else (State.CHASE if memory_left > 0.0 else State.INVESTIGATE)
		State.CRAWL: _crawl(delta)
	_update_zombie_audio(delta)
	if absf(velocity.x) > 4.0:
		_set_facing(1 if velocity.x > 0.0 else -1)
	_update_state_label()
	move_and_slide()

func _wander(delta: float) -> void:
	state_left -= delta
	if state_left <= 0.0:
		velocity.x = ([-1.0, 1.0][randi() % 2]) * walk_speed * randf_range(0.7, 1.15)
		_play_animation("walk")
		state_left = randf_range(wander_pause_min, wander_pause_max)
	if global_position.distance_to(wander_origin) > wander_radius:
		velocity.x = signf(wander_origin.x - global_position.x) * walk_speed

func _investigate(delta: float) -> void:
	var dx := noise_position.x - global_position.x
	if absf(dx) > FACING_DEADZONE:
		_set_facing(1 if dx > 0.0 else -1)
	if lost_target_search_pending:
		if absf(dx) > 10.0:
			velocity.x = signf(dx) * (crawl_speed if _is_crawler() else walk_speed)
			_play_animation("crawl" if _is_crawler() else "walk")
			return
		velocity.x = 0.0
		_play_animation("idle")
		if lost_target_search_left <= 0.0:
			_set_facing(-facing)
			lost_target_search_left = 3.0
		else:
			lost_target_search_left -= delta
			if lost_target_search_left <= 0.0:
				lost_target_search_pending = false
				state = State.WANDER
		return
	if absf(dx) <= 10.0:
		velocity.x = 0.0
		_play_animation("idle")
		if memory_left <= 0.0: state = State.WANDER
		return
	if memory_left <= 0.0:
		state = State.WANDER
		return
	velocity.x = signf(dx) * (crawl_speed if _is_crawler() else walk_speed)
	_play_animation("walk")

func _alert(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	_play_animation("idle")
	if (_can_melee_target() or _can_upward_melee_target()) and attack_left <= 0.0: _begin_attack_windup()

func _watch_high(delta: float) -> void:
	velocity.x = 0.0
	_play_animation("watch_high")
	if _can_see_upper_target(target):
		# Пока верхний луч держит игрока, не выходим в wander и не меняем
		# направление по микроскопическому смещению X.
		state_left = watch_high_duration
		return
	# Игрок пропал из верхней зоны: проверяем последнюю известную позицию.
	_begin_lost_target_search()

func _chase(delta: float) -> void:
	var sees := _can_see_target(target)
	if target == null or not sees:
		_begin_lost_target_search()
		return
	var destination := target.global_position if sees else last_known_position
	var dx := destination.x - global_position.x
	if sees and absf(dx) > FACING_DEADZONE:
		_set_facing(1 if dx > 0.0 else -1)
	if sees and _can_see_upper_target(target):
		if _can_upward_melee_target() and attack_left <= 0.0:
			velocity.x = 0.0
			_begin_attack_windup()
			return
		if absf(dx) <= FACING_DEADZONE:
			velocity.x = 0.0
			_play_animation("watch_high")
		else:
			velocity.x = signf(dx) * run_speed
			_play_animation("run")
		return
	if sees and absf(dx) <= attack_distance:
		velocity.x = 0.0
		if attack_left <= 0.0:
			_begin_attack_windup()
		else:
			state = State.ALERT
		return
	velocity.x = signf(dx) * (crawl_speed if _is_crawler() else run_speed)
	_play_animation("run")

func _attack() -> void:
	velocity.x = 0.0
	if attack_animation_left <= 0.0:
		upward_attack = _can_upward_melee_target()
		attack_direction.rotation = -PI * 0.5 if upward_attack else 0.0
		var attack_animations := ["attack", "attack2", "attack3"]
		_play_animation(attack_animations[randi() % attack_animations.size()])
		_play_zombie_sound(attack_sounds)
		attack_animation_left = 0.45
		attack_left = attack_cooldown
		attack_damage_applied = false
	else:
		attack_animation_left -= get_physics_process_delta_time()
		if not attack_damage_applied and attack_animation_left <= 0.20:
			_apply_attack_damage()
	if attack_animation_left <= 0.0:
		upward_attack = false
		attack_direction.rotation = 0.0
		state = State.CHASE

func _apply_attack_damage() -> void:
	attack_damage_applied = true
	var target_in_attack_zone := _can_upward_melee_target() if upward_attack else (_can_crawl_melee_target() if _is_crawler() else (target != null and global_position.distance_to(target.global_position) <= attack_distance + 12.0))
	if target and target_in_attack_zone:
		Signals.emit_signal("enemy_attack", attack_damage)

func _begin_attack_windup() -> void:
	if state == State.ATTACK_WINDUP: return
	state = State.ATTACK_WINDUP
	state_left = attack_windup_time
	attack_damage_applied = false
	velocity.x = 0.0
	var preparation_animation := "attack_prepare" if animated_sprite.sprite_frames.has_animation("attack_prepare") else "idle"
	_play_animation(preparation_animation)

func _attack_windup(delta: float) -> void:
	velocity.x = 0.0
	var preparation_animation := "attack_prepare" if animated_sprite.sprite_frames.has_animation("attack_prepare") else "idle"
	_play_animation(preparation_animation)
	state_left -= delta
	if state_left <= 0.0:
		state = State.ATTACK
		attack_animation_left = 0.0

func _crawl(delta: float) -> void:
	var target_seen := target != null and _can_see_target(target)
	if target != null and _can_crawl_melee_target() and attack_left <= 0.0:
		velocity.x = 0.0
		_begin_attack_windup()
		return
	var destination := target.global_position if target_seen else last_known_position
	velocity.x = move_toward(velocity.x, signf(destination.x - global_position.x) * crawl_speed, acceleration * delta)
	_play_animation("crawl")

func _begin_lost_target_search() -> void:
	noise_position = last_known_position
	lost_target_search_pending = true
	lost_target_search_left = 0.0
	if absf(noise_position.x - global_position.x) > FACING_DEADZONE:
		_set_facing(1 if noise_position.x > global_position.x else -1)
	state = State.INVESTIGATE

func _find_player() -> Node2D:
	var result := get_tree().get_first_node_in_group("player") as Node2D
	if result == null: result = get_tree().current_scene.get_node_or_null("Player/Player") as Node2D
	return result

func _can_see_target(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate): return false
	var to_target := candidate.global_position - global_position
	if to_target.length() > vision_distance: return false
	# VisionArea — основная широкая зона обнаружения. Это особенно важно
	# на лестницах: её Area2D не блокируется коллизией самой лестницы.
	if _vision_area_contains(candidate): return true
	var angle := absf(rad_to_deg(Vector2(facing, 0.0).angle_to(to_target.normalized())))
	if angle <= vision_half_angle:
		if _ray_sees_candidate(vision_ray, candidate, Vector2(0.0, -8.0)): return true
		if _ray_sees_candidate(vision_ray_high, candidate, Vector2(0.0, -28.0)): return true
		if _ray_sees_candidate(vision_ray_low, candidate, Vector2(0.0, 18.0)): return true
	return _can_see_upper_target(candidate)

func _can_see_upper_target(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate): return false
	var offset := candidate.global_position - global_position
	if offset.y >= -4.0 or offset.y < -vision_up_distance: return false
	if absf(offset.x) > vision_distance: return false
	return _vision_area_contains(candidate) or _ray_sees_candidate(vision_ray_up, candidate, Vector2(0.0, -8.0))

func _can_see_high_target(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate): return false
	var offset := candidate.global_position - global_position
	if offset.y >= -4.0 or offset.y < -vision_up_distance: return false
	if absf(offset.x) > vision_up_horizontal_tolerance: return false
	return _ray_sees_candidate(vision_ray_up, candidate, Vector2(0.0, -8.0))

func _vision_area_contains(candidate: Node2D) -> bool:
	if run_area == null or not run_area.monitoring: return false
	if not run_area.get_overlapping_bodies().has(candidate): return false

	# VisionArea сама по себе не учитывает стены и двери.
	# Дополнительно проверяем прямую видимость физическим лучом.
	var query := PhysicsRayQueryParameters2D.create(global_position, candidate.global_position, (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3))
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return true

	var collider := hit.get("collider") as Node
	return collider == candidate or (collider != null and candidate.is_ancestor_of(collider))

func _configure_vision_ray(ray: RayCast2D) -> void:
	if ray == null: return
	ray.collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3)
	ray.collide_with_bodies = true
	ray.collide_with_areas = false

func _ray_sees_candidate(ray: RayCast2D, candidate: Node2D, origin_offset: Vector2) -> bool:
	if ray == null: return false
	ray.global_position = global_position + origin_offset
	if ray != vision_ray_up:
		ray.global_rotation = PI if facing < 0 else 0.0
	else:
		ray.global_rotation = 0.0
	ray.target_position = ray.to_local(candidate.global_position)
	ray.force_raycast_update()
	return ray.is_colliding() and ray.get_collider() == candidate

func _set_facing(new_facing: int) -> void:
	if new_facing == 0 or new_facing == facing: return
	facing = new_facing
	animated_sprite.flip_h = facing < 0
	_update_vision_ray_orientation()
	_update_vision_area()

func _update_vision_ray_orientation() -> void:
	var horizontal_rotation := PI if facing < 0 else 0.0
	vision_ray.global_rotation = horizontal_rotation
	vision_ray_high.global_rotation = horizontal_rotation
	vision_ray_low.global_rotation = horizontal_rotation
	# Луч вверх не переворачивается вместе с горизонтальным взглядом.
	vision_ray_up.global_rotation = 0.0
	vision_ray.target_position = Vector2(420.0, 0.0)
	vision_ray_high.target_position = Vector2(420.0, 0.0)
	vision_ray_low.target_position = Vector2(420.0, 0.0)
	vision_ray_up.target_position = Vector2(0.0, -140.0)

func _update_vision_area() -> void:
	if vision_area == null: return
	# RunArea и JumpArea лежат внутри VisionArea, поэтому зеркалим
	# весь контейнер относительно корпуса зомби.
	vision_area.rotation = 0.0
	vision_area.scale = Vector2(float(facing), 1.0)

func _update_state_label() -> void:
	if state_label == null: return
	state_label.text = "%s\nanimation: %s\nmemory: %.1f" % [_state_name(), str(animated_sprite.animation), memory_left]

func _update_zombie_audio(delta: float) -> void:
	if zombie_audio == null: return
	if state != State.WANDER:
		wander_sound_left = randf_range(2.0, 6.0)
		return
	wander_sound_left -= delta
	if wander_sound_left <= 0.0 and not zombie_audio.playing:
		_play_zombie_sound(wander_sounds)
		wander_sound_left = randf_range(2.5, 7.0)

func _play_zombie_sound(sound_list: Array[AudioStream]) -> void:
	if zombie_audio == null or sound_list.is_empty(): return
	zombie_audio.stream = sound_list[randi() % sound_list.size()]
	zombie_audio.pitch_scale = randf_range(0.96, 1.04)
	zombie_audio.play()

func _state_name() -> String:
	match state:
		State.WANDER: return "WANDER"
		State.INVESTIGATE: return "INVESTIGATE"
		State.ALERT: return "ALERT"
		State.CHASE: return "CHASE"
		State.ATTACK_WINDUP: return "ATTACK_WINDUP"
		State.ATTACK: return "ATTACK"
		State.WATCH_HIGH: return "WATCH_HIGH"
		State.HIT: return "HIT"
		State.DEAD: return "DEAD"
		State.CRAWL: return "CRAWL"
	return "UNKNOWN"

func _can_melee_target() -> bool:
	if not is_instance_valid(target): return false
	var offset := target.global_position - global_position
	return absf(offset.x) <= attack_distance and absf(offset.y) <= upper_target_threshold

func _can_crawl_melee_target() -> bool:
	if not is_instance_valid(target): return false
	var offset := target.global_position - global_position
	return absf(offset.x) <= attack_distance + 26.0 and absf(offset.y) <= upper_target_threshold + 15.0

func _can_upward_melee_target() -> bool:
	if not is_instance_valid(target): return false
	# Границы и положение атаки полностью задаются CollisionShape2D
	# внутри HeadAttackArea и редактируются прямо в сцене.
	return head_attack_area != null and head_attack_area.monitoring and head_attack_area.get_overlapping_bodies().has(target)

## Called by the weapon. This lets a zombie investigate a shot it cannot see.
func hear_sound(position: Vector2, loudness: float = hearing_distance) -> void:
	if dead or global_position.distance_to(position) > loudness: return
	noise_position = position
	last_known_position = position
	memory_left = memory_time
	if not _can_see_target(target):
		state = State.INVESTIGATE
		state_left = 0.1

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	take_damage_at_position(amount, knockback_dir, global_position)

func take_damage_at_position(amount: int, _knockback_dir: Vector2, impact_position: Vector2) -> void:
	if dead: return
	var body_part := _body_part_at(impact_position)
	match body_part:
		BodyPart.HEAD:
			_die()
			return
		BodyPart.ARM:
			arm_hits += 1
			if arm_hits >= 2:
				_detach_arm(impact_position.x < global_position.x)
			health -= limb_damage
		BodyPart.LEG:
			leg_hits += 1
			if leg_hits >= 3:
				_detach_leg(impact_position.x < global_position.x)
			health -= limb_damage
		BodyPart.BODY: health -= int(round(float(amount) * body_damage_multiplier))
	if health <= 0:
		_die()
		return
	var reaction := "hit_body"
	if body_part == BodyPart.ARM: reaction = "hit_arm"
	elif body_part == BodyPart.LEG: reaction = "hit_leg"
	_begin_hit_reaction(reaction)

func _begin_hit_reaction(animation_name: String) -> void:
	velocity.x = 0.0
	state = State.HIT
	state_left = hit_recovery_time
	_play_zombie_sound(damage_sounds)
	_play_animation(animation_name)

func _body_part_at(world_position: Vector2) -> BodyPart:
	var p := to_local(world_position)
	if p.y < -24.0: return BodyPart.HEAD
	if p.y > 15.0: return BodyPart.LEG
	if p.y > -22.0 and p.y < 12.0: return BodyPart.ARM
	return BodyPart.BODY

func _detach_arm(left_side: bool) -> void:
	if (left_side and missing_left_arm) or (not left_side and missing_right_arm): return
	if left_side: missing_left_arm = true
	else: missing_right_arm = true
	arm_hit_shape.set_deferred("disabled", true)
	_spawn_detached_piece(Vector2(-24.0 if left_side else 24.0, -2.0), Color("#6f3535"))

func _detach_leg(left_side: bool) -> void:
	if (left_side and missing_left_leg) or (not left_side and missing_right_leg): return
	if left_side: missing_left_leg = true
	else: missing_right_leg = true
	leg_hit_shape.set_deferred("disabled", true)
	_spawn_detached_piece(Vector2(-10.0 if left_side else 10.0, 28.0), Color("#542c2c"))
	# Одной отстреленной ноги достаточно: зомби сразу переходит на ползание.
	state = State.CRAWL
	velocity.x = 0.0
	collision_shape.position.y += 18.0
	collision_shape.scale = Vector2(1.0, 0.65)

func _is_crawler() -> bool: return missing_left_leg or missing_right_leg

func _spawn_detached_piece(offset: Vector2, color: Color) -> void:
	var piece := Polygon2D.new()
	piece.polygon = PackedVector2Array([Vector2(-5, -5), Vector2(5, -4), Vector2(6, 5), Vector2(-4, 6)])
	piece.color = color
	piece.global_position = global_position + offset
	get_tree().current_scene.add_child(piece)
	var tween := piece.create_tween()
	tween.parallel().tween_property(piece, "position", piece.position + Vector2(randf_range(-30, 30), randf_range(-45, -15)), 0.45)
	tween.parallel().tween_property(piece, "modulate:a", 0.0, 0.8)
	tween.tween_callback(piece.queue_free)

func _die() -> void:
	if dead: return
	dead = true
	state = State.DEAD
	velocity = Vector2.ZERO
	if zombie_audio != null:
		zombie_audio.stream = death_sound
		zombie_audio.pitch_scale = 1.0
		zombie_audio.play()
	# Труп не принимает пули, но его форма остаётся активной для падения на землю.
	collision_layer = 0
	collision_mask = 1
	_play_animation("death")

func _on_legacy_damage(amount: int) -> void:
	if not dead: take_damage(amount)

func _play_animation(name: String) -> void:
	var animation_name := name
	if (missing_left_arm or missing_right_arm) and name in ["idle", "walk", "run"] and animated_sprite.sprite_frames.has_animation("one_arm_walk"):
		animation_name = "one_arm_walk"
	if animated_sprite.sprite_frames.has_animation(animation_name) and animated_sprite.animation != StringName(animation_name): animated_sprite.play(animation_name)
