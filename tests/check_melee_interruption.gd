extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for i in 3:
		await physics_frame
	await process_frame

func run() -> void:
	create_timer(8.0).timeout.connect(func(): quit(1))
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var p = load("res://Scene/Player/Player.tscn").instantiate()
	world.add_child(p)
	p.set_physics_process(false)
	p.set_process(false)
	p.get_node("Camera2D").enabled = false
	p.animPlayer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var dog = load("res://EnemyDog/enemy_dog.tscn").instantiate()
	world.add_child(dog)
	dog.set_physics_process(false)
	dog.set_process(false)
	# Isolate the incoming bite from the player's outgoing damage.
	dog.collision_layer = 0
	dog.get_node("Hurtbox").collision_layer = 0
	dog.get_node("Hurtbox").collision_mask = 0
	dog.attack_area.get_node("CollisionShape2D").position = Vector2.ZERO
	dog.attack_area.global_position = p.global_position
	for phase in ["normal_windup", "heavy_windup", "normal", "heavy", "charge", "idle"]:
		dog.attack_area.monitoring = false
		await settle()
		p.state = p.ON_FLOOR
		p.stamina = p.max_stamina
		p.health = p.max_health
		var heavy: bool = phase.begins_with("heavy")
		var windup: bool = phase.ends_with("windup")
		var expected_stamina: float = p.max_stamina
		if phase == "charge":
			p.melee_button_down = true
			p._begin_melee_charge()
			p._update_melee_charge(0.3)
			expected_stamina -= (0.3 - p.melee_hold_threshold) * p.heavy_hold_stamina_per_second
		elif phase != "idle":
			p._start_melee(3 if heavy else 1, heavy)
			assert(p.stamina == p.max_stamina, "Starting the windup must not spend stamina")
		await process_frame
		if phase not in ["charge", "idle"]:
			p.animPlayer.advance((0.04 if heavy else 0.15) if windup else (0.09 if heavy else 0.31))
			await process_frame
			assert(p.melee_hitbox.disabled == windup)
			if not windup:
				expected_stamina -= p.heavy_stamina_cost if heavy else p.melee_stamina_cost
				p.melee_hit_active = true
				assert(is_equal_approx(p.stamina, expected_stamina), "Charge each swing only once")
		assert(is_equal_approx(p.stamina, expected_stamina))
		var expected_shape: Shape2D = p.melee_hitbox.shape
		var was_active: bool = not p.melee_hitbox.disabled
		var verify_callback := func(body: Node2D) -> void:
			if body != p:
				return
			assert(p.melee_stage == 0, "Cancel damage immediately inside the bite callback")
			assert(p.melee_hitbox.shape == expected_shape, "Defer shape changes until queries finish")
			if was_active:
				assert(not p.melee_hitbox.disabled, "Stopping animation must not reset collision tracks inside the callback")
		dog.attack_area.body_entered.connect(verify_callback, CONNECT_ONE_SHOT)
		dog.state = dog.State.BITE
		dog.attack_active = true
		dog.has_hit_this_attack = false
		# This must enter through the real physics signal, while queries flush.
		dog.attack_area.monitoring = true
		await settle()
		assert(p.health == p.max_health - dog.bite_damage)
		assert(is_equal_approx(p.stamina, expected_stamina), "An interrupted windup is free; a committed swing keeps its cost")
		assert(p.state == p.DAMAGE and p.melee_stage == 0)
		assert(not p.melee_charging and not p.melee_button_down)
		assert(p.melee_hitbox.disabled)
		assert(p.melee_hitbox.shape == p.melee_normal_shape)
		assert(p.melee_hitbox.position == p.melee_hitbox_position)
		p._release_melee()
		p._on_melee_animation_finished(&"axe_heavy")
		assert(p.state == p.DAMAGE and p.melee_stage == 0)
		print("BITE_INTERRUPT_OK ", phase)
	world.queue_free()
	await process_frame
	print("MELEE_PHYSICS_INTERRUPTION_OK")
	quit()
