extends CharacterBody2D

@onready var arm: Node2D = $Arm
@onready var player: Node2D = get_tree().get_first_node_in_group("player")
@onready var detection_area: Area2D = $PlayerDetectionArea
@onready var demo_target: Node2D = get_node_or_null("ArmTarget")
@onready var target_proxy: Node2D = $TargetProxy

@export var tentacle_hit_radius: float = 13.0
@export var target_transition_speed: float = 90.0
@export var hits_to_kill: int = 7
@export var blood_particles_per_hit: int = 18
@export var blood_particles_on_death: int = 32
@export var showcase_eye_count: int = 3
@export var attack_distance: float = 28.0
@export var attack_cooldown: float = 1.25
@export var attack_damage: int = 10
@export var attack_knockback: Vector2 = Vector2(240.0, -180.0)
@export var attack_side_knockback: float = 140.0
@export var attack_lunge_distance: float = 55.0
@export var attack_lunge_time: float = 0.08
@export var attack_recovery_time: float = 0.26
@export var attack_windup_time: float = 1.0

var hit_shapes: Array[CollisionShape2D] = []
var desired_target: Node2D
var hits_received: int = 0
var is_dead: bool = false
var blood_texture: Texture2D
var attack_timer: float = 0.0
var attack_offset: Vector2 = Vector2.ZERO
var attack_motion_active: bool = false
var attack_motion_tween: Tween
var attack_windup_active: bool = false
var attack_windup_tween: Tween
var attack_lunge_direction: Vector2 = Vector2.RIGHT
var attack_target_position: Vector2 = Vector2.ZERO
var attack_target_locked: bool = false

func _ready() -> void:
	process_physics_priority = 10
	collision_layer = 4
	collision_mask = 0
	_apply_canvas_modulate_compensation()
	_force_opaque_tentacle()
	_setup_showcase_visuals()
	_create_tentacle_hitboxes()

	if demo_target:
		demo_target.visible = false
	desired_target = demo_target
	target_proxy.global_position = demo_target.global_position if demo_target else global_position
	arm.set("target", target_proxy)
	detection_area.body_entered.connect(_on_player_detection_area_body_entered)
	detection_area.body_exited.connect(_on_player_detection_area_body_exited)


func _apply_canvas_modulate_compensation() -> void:
	var canvas_modulate := get_tree().root.find_child("CanvasModulate", true, false) as CanvasModulate
	if canvas_modulate == null:
		return

	var darkness := canvas_modulate.color
	arm.self_modulate = Color(
		1.0 / maxf(darkness.r, 0.01),
		1.0 / maxf(darkness.g, 0.01),
		1.0 / maxf(darkness.b, 0.01),
		1.0
	)


func _force_opaque_tentacle() -> void:
	arm.modulate.a = 1.0
	arm.self_modulate.a = 1.0

	var viewport_container := arm.get_node_or_null("OutlinedSubViewportContainer") as CanvasItem
	if viewport_container:
		viewport_container.modulate.a = 1.0
		viewport_container.self_modulate.a = 1.0

	var tone_group := arm.get_node_or_null("OutlinedSubViewportContainer/SubViewport/TwoToneCanvasGroup") as CanvasItem
	if tone_group:
		tone_group.modulate.a = 1.0
		tone_group.self_modulate.a = 1.0

	var base_line := arm.get_node_or_null("OutlinedSubViewportContainer/SubViewport/TwoToneCanvasGroup/BaseLine") as Line2D
	if base_line:
		var line_color := base_line.default_color
		line_color.a = 1.0
		base_line.default_color = line_color


func _setup_showcase_visuals() -> void:
	var shadow_line := arm.get_node_or_null("OutlinedSubViewportContainer/SubViewport/ShadowCanvasGroup") as CanvasItem
	if shadow_line:
		shadow_line.visible = false

	for _index in range(maxi(0, showcase_eye_count)):
		arm.add_eye()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_timer = maxf(0.0, attack_timer - delta)
	_update_tentacle_hitboxes()
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and detection_area.has_overlapping_bodies():
		for body in detection_area.get_overlapping_bodies():
			if body == player or body.is_in_group("player"):
				desired_target = _get_player_head_target()
				break
	if not attack_windup_active and (attack_target_locked or is_instance_valid(desired_target)):
		var target_position := attack_target_position + attack_offset if attack_target_locked else desired_target.global_position + attack_offset
		var target_speed := 700.0 if attack_motion_active else target_transition_speed
		target_proxy.global_position = target_proxy.global_position.move_toward(
			target_position,
			target_speed * delta
		)
	_try_attack_player()


func take_damage(_amount: int, _direction: Vector2 = Vector2.ZERO) -> void:
	_handle_damage(_amount, _direction, global_position)


func take_damage_at_position(_amount: int, _direction: Vector2, impact_position: Vector2) -> void:
	_handle_damage(_amount, _direction, impact_position)


func _handle_damage(_amount: int, _direction: Vector2, impact_position: Vector2) -> void:
	if is_dead:
		return

	hits_received += 1
	_spawn_blood(impact_position, _direction, blood_particles_per_hit)
	if hits_received >= hits_to_kill:
		_die(_direction, impact_position)


func _spawn_blood(origin: Vector2, direction: Vector2, particle_count: int, explosion: bool = false) -> void:
	var particles := GPUParticles2D.new()
	particles.amount = particle_count
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.texture = _get_blood_texture()
	particles.process_material = _create_blood_material(direction, explosion)
	particles.global_position = origin
	get_tree().current_scene.add_child(particles)
	particles.emitting = true

	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	if is_instance_valid(particles):
		particles.queue_free()


func _create_blood_material(direction: Vector2, explosion: bool = false) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	var spray_direction := direction.normalized() if direction != Vector2.ZERO else Vector2.UP
	material.direction = Vector3(spray_direction.x, spray_direction.y, 0.0)
	material.spread = 180.0 if explosion else 55.0
	material.initial_velocity_min = 100.0 if explosion else 55.0
	material.initial_velocity_max = 280.0 if explosion else 170.0
	material.gravity = Vector3(0.0, 180.0, 0.0)
	material.scale_min = 0.55 if explosion else 0.45
	material.scale_max = 1.25 if explosion else 1.0
	material.color = Color(0.72, 0.015, 0.025, 0.95)
	return material


func _get_blood_texture() -> Texture2D:
	if blood_texture:
		return blood_texture

	var image := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	blood_texture = ImageTexture.create_from_image(image)
	return blood_texture


func _die(direction: Vector2, impact_position: Vector2) -> void:
	is_dead = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	for shape in hit_shapes:
		shape.set_deferred("disabled", true)

	detection_area.set_deferred("monitoring", false)
	_spawn_blood(impact_position, direction, blood_particles_on_death, true)

	# Pull the IK target back to the first segment so the tentacle retracts into its base.
	var segments: Array[Vector2] = arm.get_segments()
	var base_position := arm.to_global(segments[0]) if not segments.is_empty() else arm.global_position
	var death_tween := create_tween().set_parallel(true)
	death_tween.tween_property(target_proxy, "global_position", base_position, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death_tween.tween_property(arm, "modulate", Color(0.55, 0.16, 0.12, 1.0), 0.7)
	death_tween.chain().tween_callback(Callable(self, "_freeze_dead_arm"))


func _freeze_dead_arm() -> void:
	arm.set_physics_process(false)


func _get_player_head_target() -> Node2D:
	var head_target := player.get_node_or_null("AimRig/HeadPivot/HeadSprite") as Node2D
	return head_target if head_target else player


func _try_attack_player() -> void:
	if attack_timer > 0.0 or attack_windup_active or attack_motion_active or not is_instance_valid(player):
		return
	if not detection_area.get_overlapping_bodies().has(player):
		return

	var segments: Array[Vector2] = arm.get_segments()
	if segments.is_empty():
		return

	var head_target := _get_player_head_target()
	var tentacle_tip := arm.to_global(segments[-1])
	if tentacle_tip.distance_to(head_target.global_position) > attack_distance:
		return

	attack_timer = attack_cooldown
	var lunge_direction := (tentacle_tip - arm.to_global(segments[-2])).normalized()
	if lunge_direction == Vector2.ZERO:
		lunge_direction = (head_target.global_position - global_position).normalized()
	_start_attack_windup(lunge_direction, head_target.global_position)


func _start_attack_windup(direction: Vector2, target_position: Vector2) -> void:
	attack_windup_active = true
	attack_lunge_direction = direction
	attack_target_position = target_position

	var segments: Array[Vector2] = arm.get_segments()
	if segments.is_empty():
		attack_windup_active = false
		return

	var base_position := arm.to_global(segments[0])
	if attack_windup_tween and attack_windup_tween.is_valid():
		attack_windup_tween.kill()
	attack_windup_tween = create_tween()
	attack_windup_tween.tween_property(target_proxy, "global_position", base_position, attack_windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	attack_windup_tween.tween_callback(Callable(self, "_finish_attack_windup"))


func _finish_attack_windup() -> void:
	attack_windup_active = false
	attack_target_locked = true
	target_proxy.global_position = attack_target_position
	_start_attack_motion(attack_lunge_direction)

	if is_instance_valid(player):
		var head_target := _get_player_head_target()
		if head_target.global_position.distance_to(attack_target_position) <= attack_distance:
			_apply_attack_to_player(head_target)


func _apply_attack_to_player(head_target: Node2D) -> void:
	Signals.emit_signal("enemy_attack", attack_damage)

	var player_body := player as CharacterBody2D
	if player_body:
		var horizontal_direction := signf(attack_lunge_direction.x)
		if is_zero_approx(horizontal_direction):
			horizontal_direction = signf(head_target.global_position.x - global_position.x)
		if is_zero_approx(horizontal_direction):
			horizontal_direction = 1.0
		player_body.velocity = Vector2(
			horizontal_direction * attack_side_knockback,
			attack_knockback.y
		)


func _start_attack_motion(direction: Vector2) -> void:
	if attack_motion_tween and attack_motion_tween.is_valid():
		attack_motion_tween.kill()

	attack_motion_active = true
	var lunge_offset := direction * attack_lunge_distance
	attack_motion_tween = create_tween()
	attack_motion_tween.tween_property(self, "attack_offset", lunge_offset, attack_lunge_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	attack_motion_tween.tween_property(self, "attack_offset", Vector2.ZERO, attack_recovery_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	attack_motion_tween.tween_callback(Callable(self, "_finish_attack_motion"))


func _finish_attack_motion() -> void:
	attack_offset = Vector2.ZERO
	attack_motion_active = false
	attack_target_locked = false


func _create_tentacle_hitboxes() -> void:
	for shape in hit_shapes:
		shape.queue_free()
	hit_shapes.clear()

	var segments: Array[Vector2] = arm.get_segments()
	for index in range(segments.size() - 1):
		var hit_shape := CollisionShape2D.new()
		hit_shape.name = "TentacleHit_%02d" % index
		var capsule := CapsuleShape2D.new()
		capsule.radius = tentacle_hit_radius
		capsule.height = tentacle_hit_radius * 2.0 + 1.0
		hit_shape.shape = capsule
		add_child(hit_shape)
		hit_shapes.append(hit_shape)


func _update_tentacle_hitboxes() -> void:
	if not is_instance_valid(arm):
		return

	var segments: Array[Vector2] = arm.get_segments()
	if segments.size() < 2:
		return
	if hit_shapes.size() != segments.size() - 1:
		_create_tentacle_hitboxes()

	var shape_count := mini(hit_shapes.size(), segments.size() - 1)
	for index in range(shape_count):
		var from := arm.to_global(segments[index])
		var to := arm.to_global(segments[index + 1])
		var segment := to - from
		var length := segment.length()
		if length <= 0.01:
			continue

		var hit_shape := hit_shapes[index]
		hit_shape.position = to_local((from + to) * 0.5)
		hit_shape.rotation = segment.angle() + PI * 0.5
		var capsule := hit_shape.shape as CapsuleShape2D
		capsule.height = length + tentacle_hit_radius * 2.0


func _on_player_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		desired_target = _get_player_head_target()


func _on_player_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		desired_target = demo_target
