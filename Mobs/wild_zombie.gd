extends CharacterBody2D

## Быстрый зомби: неподвижный idle, затем быстрые рывки и прыжки к цели.

enum State { IDLE, CHASE, JUMP, ATTACK, HIT, DEAD }

@export_category("Movement")
@export var run_speed := 145.0
@export var walk_speed := 100.0
@export var run_transition_distance := 180.0
@export var jump_speed := 185.0
@export var jump_velocity := -330.0
@export var gravity := 980.0
@export var jump_cooldown := 0.75
@export_range(0.0, 1.0) var jump_chance := 0.55
@export var run_before_jump_min := 1.0
@export var run_before_jump_max := 2.8
@export var jump_interval_min := 0.8
@export var jump_interval_max := 2.2
@export_category("Perception")
@export var vision_distance := 520.0
@export var vision_half_angle := 55.0
@export var hearing_distance := 700.0
@export var memory_time := 5.0
@export_category("Combat")
@export var attack_distance := 42.0
@export var level_tolerance := 45.0
@export var attack_damage := 10
@export var attack_cooldown := 0.9
@export var max_health := 70

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision_ray: RayCast2D = $VisionRay
@onready var vision_area: Area2D = $VisionArea
@onready var body_shape: CollisionShape2D = $BodyShape
@onready var attack_area: Area2D = $AttackArea

var state := State.IDLE
var health: int
var target: Node2D
var last_known_position := Vector2.ZERO
var memory_left := 0.0
var jump_left := 0.0
var movement_phase_left := 0.0
var movement_mode := 0 # 0 = run, 1 = walk
var attack_left := 0.0
var attack_animation_left := 0.0
var hit_reaction_left := 0.0
var jump_hit := false
var dead := false
var facing := 1

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("zombies")
	add_to_group("wild_zombies")
	health = max_health
	movement_phase_left = randf_range(run_before_jump_min, run_before_jump_max)
	movement_mode = 0
	vision_ray.collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3)
	_setup_animations()
	_update_vision_area()
	_play("idle")

func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	jump_left = maxf(0.0, jump_left - delta)
	movement_phase_left = maxf(0.0, movement_phase_left - delta)
	attack_left = maxf(0.0, attack_left - delta)
	memory_left = maxf(0.0, memory_left - delta)
	hit_reaction_left = maxf(0.0, hit_reaction_left - delta)
	attack_animation_left = maxf(0.0, attack_animation_left - delta)
	target = _find_player()
	var sees := _can_see(target)
	if hit_reaction_left > 0.0:
		state = State.HIT
	elif state not in [State.JUMP, State.ATTACK] and (sees or memory_left > 0.0):
		if state == State.IDLE:
			movement_phase_left = randf_range(run_before_jump_min, run_before_jump_max)
		if sees:
			last_known_position = target.global_position
			memory_left = memory_time
		state = State.CHASE

	match state:
		State.IDLE: _idle()
		State.CHASE: _chase(delta, sees)
		State.JUMP: _jump_attack(delta)
		State.ATTACK: _attack()
		State.HIT:
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if hit_reaction_left <= 0.0: state = State.CHASE if memory_left > 0.0 else State.IDLE

	if absf(velocity.x) > 1.0:
		facing = 1 if velocity.x > 0.0 else -1
		animated_sprite.flip_h = facing < 0
		_update_vision_area()
	move_and_slide()

func _idle() -> void:
	velocity.x = 0.0
	_play("idle")

func _update_vision_area() -> void:
	if not is_instance_valid(vision_area): return
	vision_area.position.x = 260.0 * float(facing)
	vision_area.scale = Vector2.ONE

func _chase(_delta: float, sees: bool) -> void:
	var destination := target.global_position if sees and target else last_known_position
	var dx := destination.x - global_position.x
	var dy := destination.y - global_position.y
	if target and absf(dx) <= attack_distance and absf(dy) > level_tolerance:
		velocity.x = 0.0
		_play("idle")
		return
	if sees and _can_melee_target() and attack_left <= 0.0:
		state = State.ATTACK
		return
	if movement_phase_left <= 0.0:
		if jump_left <= 0.0 and absf(dx) <= vision_distance and randf() < jump_chance:
			_begin_jump()
			return
		movement_mode = 1 if randf() < 0.5 else 0
		movement_phase_left = randf_range(run_before_jump_min, run_before_jump_max)
	var close_to_player := sees and absf(dx) <= run_transition_distance
	var speed := run_speed if close_to_player else walk_speed
	velocity.x = signf(dx) * speed
	_play("run" if close_to_player else "walk")

func _begin_jump() -> void:
	state = State.JUMP
	jump_hit = false
	jump_left = jump_cooldown
	movement_phase_left = randf_range(jump_interval_min, jump_interval_max)
	movement_mode = 0
	var direction := signf((target.global_position.x if target else last_known_position.x) - global_position.x)
	if is_zero_approx(direction): direction = facing
	facing = int(direction)
	animated_sprite.flip_h = facing < 0
	velocity.x = direction * jump_speed
	velocity.y = jump_velocity
	_play("jump")

func _jump_attack(delta: float) -> void:
	if target and not jump_hit:
		if global_position.distance_to(target.global_position) <= attack_distance + 26.0 and absf(global_position.y - target.global_position.y) < 60.0:
			jump_hit = true
			Signals.emit_signal("enemy_attack", attack_damage)
	velocity.x = move_toward(velocity.x, 0.0, 180.0 * delta)
	if is_on_floor() and velocity.y >= 0.0:
		state = State.CHASE if memory_left > 0.0 else State.IDLE

func _attack() -> void:
	velocity.x = 0.0
	if attack_animation_left > 0.0: return
	if attack_left > 0.0:
		state = State.CHASE
		return
	_play(["attack_1", "attack_2", "attack_3"][randi() % 3])
	attack_animation_left = 0.45
	attack_left = attack_cooldown
	if _can_melee_target():
		Signals.emit_signal("enemy_attack", attack_damage)
	if attack_animation_left <= 0.0: state = State.CHASE

func _find_player() -> Node2D:
	var result := get_tree().get_first_node_in_group("player") as Node2D
	if result == null: result = get_tree().current_scene.get_node_or_null("Player/Player") as Node2D
	return result

func _can_melee_target() -> bool:
	if not is_instance_valid(target): return false
	var offset := target.global_position - global_position
	return absf(offset.x) <= attack_distance and absf(offset.y) <= level_tolerance

func _can_see(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate): return false
	var to_target := candidate.global_position - global_position
	if to_target.length() > vision_distance: return false
	if rad_to_deg(Vector2(facing, 0.0).angle_to(to_target.normalized())) > vision_half_angle: return false
	vision_ray.target_position = to_target
	vision_ray.force_raycast_update()
	return not vision_ray.is_colliding() or vision_ray.get_collider() == candidate

func hear_sound(position: Vector2, loudness: float = hearing_distance) -> void:
	if dead or global_position.distance_to(position) > loudness: return
	last_known_position = position
	memory_left = memory_time
	movement_phase_left = randf_range(run_before_jump_min, run_before_jump_max)
	movement_mode = 0
	state = State.CHASE

func take_damage(amount: int, _direction: Vector2 = Vector2.ZERO) -> void:
	if dead: return
	health -= amount
	if health <= 0:
		_die()
		return
	hit_reaction_left = 0.35
	state = State.HIT
	_play("hurt")

func _die() -> void:
	dead = true
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 1
	_play("dead")

func _play(animation_name: String) -> void:
	if animated_sprite.sprite_frames.has_animation(animation_name) and animated_sprite.animation != StringName(animation_name):
		animated_sprite.play(animation_name)

func _setup_animations() -> void:
	var frames := animated_sprite.sprite_frames
	_add_sheet_animation(frames, "run", "res://Sprites/Wild Zombie/Run.png", 8, true, 12.0)
	_add_sheet_animation(frames, "walk", "res://Sprites/Wild Zombie/Walk.png", 10, true, 10.0)
	_add_sheet_animation(frames, "jump", "res://Sprites/Wild Zombie/Jump.png", 6, false, 10.0)
	_add_sheet_animation(frames, "attack_1", "res://Sprites/Wild Zombie/Attack_1.png", 4, false, 10.0)
	_add_sheet_animation(frames, "attack_2", "res://Sprites/Wild Zombie/Attack_2.png", 4, false, 10.0)
	_add_sheet_animation(frames, "attack_3", "res://Sprites/Wild Zombie/Attack_3.png", 4, false, 10.0)
	_add_sheet_animation(frames, "hurt", "res://Sprites/Wild Zombie/Hurt.png", 5, false, 10.0)
	_add_sheet_animation(frames, "dead", "res://Sprites/Wild Zombie/Dead.png", 5, false, 8.0)

func _add_sheet_animation(frames: SpriteFrames, animation_name: String, path: String, frame_count: int, looped: bool, speed: float) -> void:
	if frames.has_animation(animation_name): return
	var texture := load(path) as Texture2D
	if texture == null: return
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, looped)
	frames.set_animation_speed(animation_name, speed)
	for frame_index in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame_index * 96, 0, 96, 96)
		frames.add_frame(animation_name, atlas)
