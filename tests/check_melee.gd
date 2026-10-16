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
    var dog = load("res://EnemyDog/enemy_dog.tscn").instantiate()
    var insect = load("res://FlyingInsect/flying_insect.tscn").instantiate()
    scene.add_child(dog)
    scene.add_child(insect)
    dog.hp = 1000
    insect.hp = 1000
    for count in [1, 2, 3]:
        p.stamina = p.max_stamina
        p.state = p.ATTACK
        p._start_melee(1)
        var before_dog = dog.hp
        var before_insect = insect.hp
        var total := 0
        for stage in range(1, count + 1):
            assert(p.melee_stage == stage)
            await process_frame
            p.animPlayer.advance([0.31, 0.18, 0.21][stage - 1])
            await process_frame
            assert(p.stamina == p.max_stamina - stage * p.melee_stamina_cost)
            var damage := int(round(p.damage_basic * p.damage_multiplier))
            total += damage
            p._melee_hit(dog)
            p._melee_hit(dog)
            p._melee_hit(insect)
            p._melee_hit(insect)
            await process_frame
            assert(dog.hp == before_dog - total)
            assert(insect.hp == before_insect - total)
            p.combo1()
            p.melee_queued = stage < count
            p._on_melee_animation_finished([&"attack", &"attack2", &"attack3"][stage - 1])
        assert(p.state == p.ON_FLOOR)
        assert(p.melee_stage == 0)
        print("COMBO_OK ", count, " hits, damage ", total)
    p.state = p.ATTACK
    p._start_melee(1)
    p._on_damage_received(1)
    var hp = dog.hp
    p._melee_hit(dog)
    await process_frame
    assert(dog.hp == hp)
    assert(p.melee_stage == 0)
    print("MELEE_CHECK_OK: single/double/triple, both enemies, deduplication, interruption")
    scene.queue_free()
    await process_frame
    quit()
