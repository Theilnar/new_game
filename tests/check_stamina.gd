extends SceneTree

func _initialize():
	run.call_deferred()

func run():
	var scene = load("res://box_push.tscn").instantiate()
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var p = scene.get_node("Player/Player")
	var bar = scene.get_node("CanvasLayer/stamina_bar")
	assert(bar.value == p.max_stamina)
	p.state = p.ATTACK
	p.stamina = p.melee_stamina_cost
	p._start_melee(1)
	assert(p.stamina == p.melee_stamina_cost, "Do not charge for the windup")
	await process_frame
	p.animPlayer.advance(0.31)
	await process_frame
	assert(p.stamina == 0.0 and bar.value == 0.0)
	p.combo = true
	p.melee_queued = true
	p._on_melee_animation_finished(&"attack")
	assert(p.state == p.ON_FLOOR and p.melee_stage == 0)
	p.state = p.ATTACK
	p._start_melee(1)
	assert(p.melee_stage == 0 and p.stamina == 0.0)
	p._update_stamina(0.5)
	assert(p.stamina == 0.0)
	p._update_stamina(1.0)
	assert(is_equal_approx(p.stamina, 12.5))
	assert(not p._can_sprint())
	p._update_stamina(0.5)
	assert(p._can_sprint())
	p._update_stamina(10.0)
	assert(p.stamina == p.max_stamina)
	Input.action_press("run")
	Input.action_press("right")
	p.velocity.x = 120.0
	for i in 5:
		p._update_stamina(1.0)
	assert(p.stamina == 0.0 and not p._can_sprint())
	assert(p.RUN_SPEED == 1)
	Input.action_release("run")
	Input.action_release("right")
	assert(bar.value == p.stamina)
	assert(scene.get_node("CanvasLayer/Ammo").offset_top > bar.offset_bottom)
	print("STAMINA_OK: attack cost, combo limit, regeneration delay, exhaustion, sprint drain, HUD")
	p.stamina = 40.0
	p._update_breathing(2.0)
	assert(not p._breathing_player.playing)
	p.stamina = 20.0
	p._update_breathing(0.1)
	assert(p._breathing_player.playing and p._breathing_volume < 0.5)
	p._update_breathing(2.0)
	assert(is_equal_approx(p._breathing_volume, 0.5))
	var quiet_db = p._breathing_player.volume_db
	p.stamina = 0.0
	p._update_breathing(2.0)
	assert(p._breathing_player.volume_db > quiet_db)
	assert(p._breathing_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(p._breathing_player.stream.loop_end > 0)
	p.stamina = 50.0
	p._update_breathing(0.1)
	assert(p._breathing_player.playing)
	p._update_breathing(2.0)
	assert(not p._breathing_player.playing)
	p.stamina = 0.0
	p._update_breathing(2.0)
	p.is_dead = true
	p._update_breathing(2.0)
	assert(not p._breathing_player.playing)
	print("BREATHING_OK: threshold, smooth volume, exhaustion, loop, recovery and death fade")
	scene.queue_free()
	await process_frame
	quit()
