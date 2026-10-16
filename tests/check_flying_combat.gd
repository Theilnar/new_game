extends SceneTree

class PlayerTarget extends CharacterBody2D:
	var is_dead: bool = false

var damage_received: int = 0
var insect
var player: PlayerTarget
var world: Node2D

func _initialize() -> void:
	run.call_deferred()

func reset_encounter() -> void:
	insect._cancel_attack()
	insect.state = insect.State.WANDER
	insect.attack_cooldown_timer = 0.0
	insect.global_position = Vector2.ZERO
	insect.velocity = Vector2.ZERO
	insect.hp = 100
	player.global_position = Vector2(80, 0)
	player.is_dead = false
	damage_received = 0

func prepare_attack() -> void:
	insect._update_player_target()
	assert(insect.state == insect.State.CHASE)
	insect._try_attack()
	assert(insect.state == insect.State.WINDUP)
	assert(insect.velocity == Vector2.ZERO)
	assert(damage_received == 0, "Approaching and preparing cannot deal damage")

func settle() -> void:
	for i in 3:
		await physics_frame
	await process_frame

func run() -> void:
	create_timer(10.0).timeout.connect(func(): quit(1))
	world = Node2D.new()
	root.add_child(world)
	current_scene = world
	player = PlayerTarget.new()
	player.add_to_group("player")
	player.collision_layer = 2
	player.collision_mask = 0
	var player_collision := CollisionShape2D.new()
	var player_shape := CircleShape2D.new()
	player_shape.radius = 10.0
	player_collision.shape = player_shape
	player.add_child(player_collision)
	world.add_child(player)
	insect = load("res://FlyingInsect/flying_insect.tscn").instantiate()
	insect.speed_variation = 0.0
	world.add_child(insect)
	insect.set_physics_process(false)
	root.get_node("Signals").enemy_attack.connect(func(amount): damage_received += amount)
	reset_encounter()
	prepare_attack()
	var locked_position: Vector2 = insect.attack_target_position
	player.position = Vector2(80, 150)
	insect._physics_process(0.44)
	assert(insect.state == insect.State.WINDUP and insect.position == Vector2.ZERO)
	assert(insect.attack_target_position == locked_position and damage_received == 0)
	assert(insect.sprite.animation == &"attack" and not insect.sprite.is_playing())
	insect._physics_process(0.011)
	assert(insect.state == insect.State.DASH)
	assert(is_equal_approx(insect.velocity.length(), insect.attack_dash_speed))
	assert(insect.attack_dash_speed > insect.chase_speed * 2.0)
	assert(insect.sprite.is_playing())
	await settle()
	insect._physics_process(0.5)
	assert(insect.position.is_equal_approx(locked_position), "Dash must stop at the original position, even with a large delta")
	assert(insect.state == insect.State.WANDER and damage_received == 0)
	assert(insect.player_target == null and insect.collision_mask == insect.flight_collision_mask)
	assert(insect.sprite.animation == &"fly")
	insect._physics_process(insect.attack_cooldown * 0.5)
	assert(insect.state in [insect.State.WANDER, insect.State.AVOID])
	assert(insect.player_target == null)
	assert(insect.velocity.length() <= insect.move_speed * insect.recovery_speed_multiplier + 0.01)
	player.position = insect.position + Vector2(80, 0)
	insect._physics_process(insect.attack_cooldown * 0.5 + 0.01)
	assert(insect.state == insect.State.WINDUP, "Find the player again after free flight")
	print("FLYING_DODGE_OK: stationary 0.45s windup, locked target, fast dash, dodge, flight and reacquisition")

	reset_encounter()
	player.position = Vector2(1000, 0)
	insect._finish_attack()
	# Returning home must obey the same recovery speed as ordinary wandering.
	insect.home_position = Vector2(-1000, 0)
	insect._physics_process(insect.attack_cooldown * 0.5)
	assert(is_equal_approx(insect.velocity.length(), insect.move_speed * insect.recovery_speed_multiplier))
	insect._physics_process(insect.attack_cooldown * 0.5 + 0.01)
	assert(insect.attack_cooldown_timer == 0.0)
	assert(is_equal_approx(insect.velocity.length(), insect.move_speed), "Normal search speed returns after recovery")
	insect.home_position = Vector2.ZERO
	insect.velocity = Vector2.ZERO
	player.position = insect.position + Vector2(150, 0)
	insect._physics_process(0.8)
	assert(insect.state == insect.State.CHASE)
	assert(is_equal_approx(insect.velocity.length(), insect.chase_speed), "Pursuit uses its full speed")
	print("FLYING_RECOVERY_SPEED_OK: slow recovery, home return, normal search and chase speeds restored")

	reset_encounter()
	prepare_attack()
	insect._physics_process(0.46)
	await settle()
	insect._physics_process(0.5)
	assert(damage_received == insect.attack_damage, "Swept collision must hit once without tunneling")
	assert(insect.state == insect.State.WANDER and insect.position.x < player.position.x)
	insect._physics_process(0.1)
	assert(damage_received == insect.attack_damage, "No contact damage after the dash")
	print("FLYING_HIT_OK: collision damage once, no tunneling, cooldown")

	reset_encounter()
	var wall := StaticBody2D.new()
	wall.position = Vector2(40, 0)
	var wall_collision := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(10, 80)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	world.add_child(wall)
	prepare_attack()
	insect._physics_process(0.46)
	await settle()
	insect._physics_process(0.5)
	assert(insect.position.x < wall.position.x and damage_received == 0)
	assert(insect.state == insect.State.WANDER)
	wall.queue_free()
	await settle()
	print("FLYING_WALL_OK: walls stop dashes and protect the player")

	for phase in ["windup", "dash"]:
		reset_encounter()
		prepare_attack()
		if phase == "dash":
			insect._physics_process(0.46)
		insect.take_damage(1, Vector2.LEFT)
		assert(insect.state == insect.State.STUN)
		assert(insect.player_target == null and insect.collision_mask == insect.flight_collision_mask)
		insect._physics_process(0.3)
		assert(insect.state == insect.State.WANDER and damage_received == 0)
		insect._physics_process(0.01)
		assert(insect.state in [insect.State.WANDER, insect.State.AVOID])
	reset_encounter()
	prepare_attack()
	insect._physics_process(0.46)
	insect.take_damage(100)
	assert(insect.state == insect.State.DEAD and insect.player_target == null)
	insect._physics_process(0.1)
	assert(damage_received == 0)
	for phase in ["windup", "dash"]:
		reset_encounter()
		prepare_attack()
		if phase == "dash":
			insect._physics_process(0.46)
		player.is_dead = true
		insect._physics_process(0.1)
		assert(insect.state == insect.State.WANDER and damage_received == 0)
	print("FLYING_CANCEL_OK: hitstun, enemy death and player death cancel attacks")

	reset_encounter()
	player.position = Vector2(190, 0)
	for i in 150:
		insect._physics_process(1.0 / 60.0)
		if insect.state == insect.State.WINDUP:
			break
	assert(insect.state == insect.State.WINDUP)
	assert(insect.position.distance_to(player.position) <= insect.attack_range)
	assert(insect.position.distance_to(player.position) > 60.0)
	assert(damage_received == 0)
	print("FLYING_APPROACH_OK: approaches before stopping to prepare")
	world.queue_free()
	await process_frame
	print("FLYING_COMBAT_OK")
	quit()
