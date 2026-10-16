extends SceneTree

class Target extends CharacterBody2D:
	var hp: int = 1000
	func take_damage(amount: int, _direction: Vector2 = Vector2.ZERO) -> void:
		hp -= amount

var p
var world: Node2D
var viewport: SubViewport

func _initialize() -> void:
	run.call_deferred()

func mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	event.position = viewport.get_mouse_position()
	viewport.push_input(event, true)

func aim_at(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = p.get_viewport_transform() * point
	viewport.push_input(event, true)

func reset_player() -> void:
	if p.melee_charging:
		p._cancel_melee_charge()
	p._clear_melee_attack()
	p.melee_button_down = false
	p.attack_cooldown = false
	p.state = p.ON_FLOOR
	p.stamina = p.max_stamina
	p.stamina_rest_timer = 0.0
	p.velocity = Vector2.ZERO

func make_target(offset: Vector2) -> Target:
	var target := Target.new()
	target.collision_layer = 8
	target.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	collision.shape = shape
	target.add_child(collision)
	world.add_child(target)
	target.global_position = p.global_position + offset
	return target

func settle_collisions() -> void:
	for i in 3:
		await physics_frame
	await process_frame

func run() -> void:
	create_timer(8.0).timeout.connect(func(): quit(1))
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	root.add_child(viewport)
	world = Node2D.new()
	world.position = Vector2(400, 300)
	viewport.add_child(world)
	current_scene = viewport
	var floor_body := StaticBody2D.new()
	var floor_collision := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(2000, 20)
	floor_collision.shape = floor_shape
	floor_body.position = Vector2(0, 35)
	floor_body.add_child(floor_collision)
	world.add_child(floor_body)
	p = load("res://Scene/Player/Player.tscn").instantiate()
	world.add_child(p)
	p.get_node("Camera2D").enabled = false
	for i in 6:
		await physics_frame
	assert(p.is_on_floor(), "Test player must stand on a real floor")
	p.set_physics_process(false)
	p.set_process(false)
	p.animPlayer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	reset_player()

	var bindings := InputMap.action_get_events("attack")
	assert(bindings.size() == 1 and bindings[0] is InputEventMouseButton)
	assert(bindings[0].button_index == MOUSE_BUTTON_RIGHT)
	var old_key := InputEventKey.new()
	old_key.physical_keycode = KEY_E
	old_key.pressed = true
	viewport.push_input(old_key, true)
	assert(not p.melee_charging, "E must no longer attack")
	p.is_near_barrier = true
	p.break_timer = p.break_time - 0.5
	mouse_button(true)
	assert(not p.is_near_barrier and p.break_timer == 0.0)
	mouse_button(false)
	reset_player()

	# Actual viewport mouse input: face away from movement, then lock the swing.
	aim_at(p.global_position + Vector2(-100, -20))
	assert(p.get_global_mouse_position().x < p.global_position.x)
	mouse_button(true)
	assert(p.melee_charging and p.anim.flip_h)
	assert(not p.can_player_shoot())
	assert(p.anim.visible and not p.aim_rig.visible and not p.legs_anim.visible)
	p._update_melee_charge(0.1)
	assert(p.stamina == 100.0, "Tap grace must not drain stamina")
	mouse_button(false)
	assert(p.melee_stage == 1 and not p.melee_is_heavy and p.stamina == p.max_stamina)
	assert(p.anim.flip_h)
	var attack_rotation: float = p.get_node("AttackDirection").rotation
	aim_at(p.global_position + Vector2(100, -20))
	p.update_aim_rig()
	assert(p.anim.flip_h and is_equal_approx(p.get_node("AttackDirection").rotation, attack_rotation))
	assert(p.melee_hitbox.disabled)
	await process_frame
	p.animPlayer.advance(0.31)
	await process_frame
	assert(not p.melee_hitbox.disabled)
	assert(p.stamina == p.max_stamina - p.melee_stamina_cost)
	mouse_button(true)
	mouse_button(false)
	p.combo1()
	p._on_melee_animation_finished(&"attack")
	assert(p.melee_stage == 2 and not p.anim.flip_h and p.stamina == p.max_stamina - p.melee_stamina_cost)
	await process_frame
	p.animPlayer.advance(0.18)
	await process_frame
	assert(p.stamina == p.max_stamina - 2.0 * p.melee_stamina_cost)
	print("AXE_INPUT_OK: RMB, E removed, tap cost, cursor facing, swing lock, combo")

	# Holding a combo input begins a separate windup when the current hit ends.
	mouse_button(true)
	p._on_melee_animation_finished(&"attack2")
	assert(p.melee_charging and p.melee_stage == 0)
	mouse_button(false)
	reset_player()

	# Readiness never auto-fires; holding drains stamina without regeneration.
	mouse_button(true)
	p.animPlayer.advance(0.2)
	assert(p.anim.animation == &"attack3" and p.anim.frame == 1)
	p._update_melee_charge(p.heavy_charge_time)
	var after_charge: float = p.stamina
	assert(is_equal_approx(after_charge, 100.0 - (p.heavy_charge_time - p.melee_hold_threshold) * p.heavy_hold_stamina_per_second))
	p._update_stamina(1.0)
	assert(p.stamina == after_charge)
	p._update_melee_charge(1.0)
	assert(p.melee_charging and p.melee_stage == 0)
	assert(is_equal_approx(p.stamina, after_charge - p.heavy_hold_stamina_per_second))
	aim_at(p.global_position + Vector2(-100, -20))
	p._update_melee_charge(0.0)
	assert(p.anim.flip_h)
	p.stamina = p.heavy_stamina_cost
	mouse_button(false)
	assert(p.melee_is_heavy and p.melee_stage == 3 and p.stamina == p.heavy_stamina_cost)
	assert(p.animPlayer.current_animation == &"axe_heavy")
	await process_frame
	assert(p.melee_hitbox.shape.radius > p.melee_normal_shape.radius)
	assert(not p.can_player_shoot())
	p.animPlayer.advance(0.09)
	await process_frame
	assert(p.stamina == 0.0)
	p._on_melee_animation_finished(&"axe_heavy")
	await process_frame
	assert(p.melee_hitbox.shape == p.melee_normal_shape)
	assert(p.melee_hitbox.position == p.melee_hitbox_position)
	print("AXE_CHARGE_OK: preparation pose, hold drain, no regen/autofire, swing cost, shape reset")

	# Exhaustion, damage, focus loss and water must discard the pending release.
	reset_player()
	mouse_button(true)
	p._update_melee_charge(p.heavy_charge_time)
	p.stamina = p.heavy_stamina_cost + 0.5
	p._update_melee_charge(0.1)
	assert(not p.melee_charging and p.state == p.ON_FLOOR)
	var after_cancel: float = p.stamina
	mouse_button(false)
	assert(p.melee_stage == 0 and p.stamina == after_cancel)
	assert(p.can_player_shoot())
	reset_player()
	p.stamina = p.melee_stamina_cost
	mouse_button(true)
	p._update_melee_charge(0.1)
	mouse_button(false)
	assert(p.melee_stage == 1 and p.stamina == p.melee_stamina_cost)
	await process_frame
	p.animPlayer.advance(0.31)
	await process_frame
	assert(p.stamina == 0.0)
	reset_player()
	p.stamina = p.melee_stamina_cost
	mouse_button(true)
	p._update_melee_charge(p.melee_hold_threshold + 0.01)
	assert(not p.melee_charging)
	mouse_button(false)
	assert(p.melee_stage == 0)
	for interruption in ["damage", "focus", "water"]:
		reset_player()
		mouse_button(true)
		p._update_melee_charge(0.3)
		if interruption == "damage":
			p._on_damage_received(1)
		elif interruption == "focus":
			p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		else:
			p.water_collision = true
			p.update_state()
			assert(p.state == p.IN_WATER)
			p.water_collision = false
		mouse_button(false)
		assert(not p.melee_charging and p.melee_stage == 0)
	print("AXE_CANCEL_OK: exhaustion, exact normal cost, damage, focus loss, water, no release hit")

	# Real collision areas: a strong swing hits multiple front targets once,
	# reaches farther than the normal swing and never hits behind the player.
	for side in [-1.0, 1.0]:
		reset_player()
		aim_at(p.global_position + Vector2(side * 150, -20))
		await process_frame
		var center_x: float = absf(p.melee_hitbox.global_position.x - p.global_position.x)
		var normal_radius: float = p.melee_normal_shape.radius
		var heavy_edge: float = center_x + p.heavy_reach_bonus + p.melee_heavy_shape.radius
		var near_target := make_target(Vector2(side * center_x, -12))
		var far_target := make_target(Vector2(side * (center_x + normal_radius + heavy_edge) * 0.5, -12))
		var outside_target := make_target(Vector2(side * (heavy_edge + 20.0), -12))
		var behind_target := make_target(Vector2(-side * (heavy_edge + 20.0), -12))
		await settle_collisions()
		mouse_button(true)
		mouse_button(false)
		await process_frame
		p.animPlayer.advance(0.31)
		await settle_collisions()
		assert(near_target.hp == 990 and far_target.hp == 1000)
		p._on_melee_animation_finished(&"attack")
		reset_player()
		mouse_button(true)
		p._update_melee_charge(p.heavy_charge_time)
		await settle_collisions()
		assert(far_target.hp == 1000, "Preparation cannot deal damage")
		mouse_button(false)
		await process_frame
		p.animPlayer.advance(0.09)
		await settle_collisions()
		assert(near_target.hp == 965 and far_target.hp == 975)
		assert(outside_target.hp == 1000 and behind_target.hp == 1000)
		await settle_collisions()
		assert(near_target.hp == 965 and far_target.hp == 975, "One hit per target per swing")
		p.animPlayer.advance(0.6)
		await process_frame
		assert(p.melee_stage == 0 and p.melee_hitbox.disabled)
		for target in [near_target, far_target, outside_target, behind_target]:
			target.queue_free()
		await process_frame
	print("AXE_AREA_OK: both sides, greater reach, multiple targets, no rear hit, deduplication, recovery")
	reset_player()
	p.animPlayer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	p.set_physics_process(true)
	p.set_process(true)
	mouse_button(true)
	await create_timer(0.5).timeout
	assert(p.melee_charging and p.melee_charge_elapsed >= p.heavy_charge_time)
	assert(p.anim.frame == 1 and p.melee_hitbox.disabled)
	mouse_button(false)
	assert(p.melee_is_heavy)
	await create_timer(0.8).timeout
	assert(p.state == p.ON_FLOOR and p.melee_stage == 0 and p.can_player_shoot())
	assert(p.weapon.visible and p.aim_rig.visible and not p.anim.visible)
	Input.action_press("right")
	await create_timer(0.1).timeout
	Input.action_release("right")
	assert(p.velocity.x > 0.0)
	p.set_physics_process(false)
	reset_player()
	mouse_button(true)
	p._enter_death_state()
	mouse_button(false)
	assert(not p.melee_charging and p.melee_stage == 0 and not p.weapon.visible)
	print("AXE_RUNTIME_OK: full physics loop, held pose, release, recovery, movement and death")
	viewport.queue_free()
	await process_frame
	print("AXE_CONTROLS_OK")
	quit()
