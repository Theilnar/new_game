extends SceneTree

func _initialize():
	run.call_deferred()

func run():
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var weapon = load("res://Scene/Weapon.tscn").instantiate()
	world.add_child(weapon)
	weapon.position = Vector2(100, 100)
	var casing = weapon.spawn_weapon_debris(false)
	assert(casing.linear_velocity.y < 0 and casing.linear_velocity.x < 0)
	assert(casing.collision_layer == 0 and casing.collision_mask == 1)
	weapon.set_aim_facing(false)
	var left_casing = weapon.spawn_weapon_debris(false)
	assert(left_casing.linear_velocity.x > 0)
	var count = get_nodes_in_group("weapon_debris").size()
	weapon.ammo_in_magazine = 0
	weapon.shoot()
	assert(get_nodes_in_group("weapon_debris").size() == count)
	weapon.ammo_in_magazine = 2
	weapon.shoot()
	assert(get_nodes_in_group("weapon_debris").size() == count + 1)
	weapon.reload_time = 0.1
	weapon.reload()
	assert(get_nodes_in_group("weapon_debris").size() == count + 2)
	var magazine = get_nodes_in_group("weapon_debris").back()
	assert(magazine.is_magazine and magazine.linear_velocity.y > 0)
	weapon.reload()
	assert(get_nodes_in_group("weapon_debris").size() == count + 2)
	await create_timer(0.3).timeout
	assert(weapon.ammo_in_magazine == weapon.magazine_size)
	weapon.reload()
	assert(get_nodes_in_group("weapon_debris").size() == count + 2)
	print("WEAPON_DEBRIS_OK: direction, physics, successful shots only, reload once, full magazine guard")
	world.queue_free()
	await process_frame
	quit()
