extends SceneTree
var damage := 0
func _initialize():
    run.call_deferred()
func run():
    var world := Node2D.new()
    root.add_child(world)
    current_scene = world
    var dog = load("res://EnemyDog/enemy_dog.tscn").instantiate()
    world.add_child(dog)
    dog.set_physics_process(false)
    var target := CharacterBody2D.new()
    target.add_to_group("player")
    target.collision_layer = 2
    var shape := CollisionShape2D.new()
    var capsule := CapsuleShape2D.new()
    capsule.radius = 9
    capsule.height = 32
    shape.shape = capsule
    target.add_child(shape)
    world.add_child(target)
    target.position = Vector2(34, -16)
    dog.player = target
    dog.facing_dir = 1
    dog._update_sensors()
    root.get_node("Signals").enemy_attack.connect(func(amount): damage += amount)
    dog._set_state(dog.State.BITE)
    assert(dog.animated_sprite.animation == &"alert")
    dog._state_bite(0.2)
    dog._on_attack_area_body_entered(target)
    assert(damage == 0)
    dog._state_bite(0.26)
    for i in 4:
        await physics_frame
    dog._state_bite(0.01)
    dog._on_attack_area_body_entered(target)
    assert(damage == dog.bite_damage, "One hit even when target was already overlapping")
    dog._state_bite(0.2)
    assert(dog.state == dog.State.BITE, "Wait for bite animation")
    assert(not dog.attack_active)
    await dog.animated_sprite.animation_finished
    assert(dog.state == dog.State.RETREAT)
    dog._on_attack_cooldown_timeout()
    assert(dog.state == dog.State.RETREAT)
    dog._set_state(dog.State.BITE)
    dog.take_damage(1, Vector2.LEFT)
    dog._on_attack_area_body_entered(target)
    assert(damage == dog.bite_damage)
    await create_timer(dog.hitstun_time + 0.05).timeout
    assert(dog.state == dog.State.RETREAT)
    dog._set_state(dog.State.BITE)
    target.position = Vector2(500, -16)
    for i in 4:
        await physics_frame
    dog._state_bite(0.46)
    for i in 4:
        await physics_frame
    dog._state_bite(0.01)
    assert(damage == dog.bite_damage, "Escaped player must not take damage")
    dog.pounce_mode_attack = true
    dog._set_state(dog.State.POUNCE)
    dog._state_pounce(0.3)
    assert(not dog.attack_active)
    assert(dog.state == dog.State.POUNCE, "Must not retreat before landing")
    print("DOG_COMBAT_OK: telegraph, overlap hit once, dodge, interrupt-retreat, airborne safety")
    world.queue_free()
    await process_frame
    quit()
