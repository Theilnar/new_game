class_name LadderController
extends RefCounted

## Owns ladder-only timers and pose intent. Player owns scene movement and animation.

var entry_time: float = 0.0
var top_drop_time: float = 0.0
var centering_time: float = 0.0
var waiting_for_area: bool = false
var side_pose: StringName = &""
var exit_animation_active: bool = false
var side_return_active: bool = false

var player

func tick(delta: float) -> void:
	entry_time = maxf(0.0, entry_time - delta)
	top_drop_time = maxf(0.0, top_drop_time - delta)
	centering_time = maxf(0.0, centering_time - delta)

func begin_entry(duration: float) -> void:
	entry_time = maxf(0.15, duration)

func set_top_drop_timer(duration: float = 0.35) -> void:
	top_drop_time = duration
	waiting_for_area = true

func side_is_blocked(direction: int) -> bool:
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var check_heights: Array[float] = [-62.0, -42.0, -22.0, 0.0]
	var collision_mask: int = player.raycast_hands_coll.collision_mask
	for height: float in check_heights:
		var from_point: Vector2 = player.global_position + Vector2(0.0, height)
		var to_point: Vector2 = from_point + Vector2(70.0 * direction, 0.0)
		var query := PhysicsRayQueryParameters2D.create(from_point, to_point, collision_mask)
		query.exclude = [player.get_rid()]
		query.collide_with_areas = false
		if not space_state.intersect_ray(query).is_empty():
			return true
	return false

func play_transition(animation_name: StringName, fallback_time: float, block_movement: bool = true) -> void:
	player.animPlayer.stop()
	player._reset_sprite_animation_speed()
	if player.anim.sprite_frames.has_animation(animation_name):
		player.anim.play(animation_name)
		var fps: float = player.anim.sprite_frames.get_animation_speed(animation_name)
		var frame_count: int = player.anim.sprite_frames.get_frame_count(animation_name)
		if block_movement:
			entry_time = maxf(0.15, float(frame_count) / maxf(fps, 1.0))
	else:
		if block_movement:
			entry_time = fallback_time
		player.animPlayer.play("ladder_climbing_ilde")

func enter_from_floor(_from_top: bool = false) -> void:
	if not Global.is_climbing:
		return
	player.velocity = Vector2.ZERO
	player.state = player.ON_LADDER
	centering_time = 0.2
	var tween: Tween = player.get_tree().create_tween()
	tween.tween_property(player, "global_position:x", player.ladder_position_x, 0.2)
	play_transition(&"ladder_enter_platform", 0.7)

func begin_top_drop() -> void:
	if not is_instance_valid(player.active_ladder_area):
		return
	var ladder_root: Node = player.active_ladder_area.get_parent()
	if not ladder_root.has_method("begin_top_drop") or not ladder_root.is_top_exit():
		return
	ladder_root.begin_top_drop()
	player.velocity = Vector2(0, 45)
	top_drop_time = 0.35
	waiting_for_area = true
	player.state = player.ON_LADDER
	var tween: Tween = player.get_tree().create_tween()
	tween.tween_property(player, "global_position:x", player.ladder_position_x, 0.2)
	play_transition(&"ladder_drop_from_top", 0.7, false)

func is_near_top_exit() -> bool:
	if not player.is_at_ladder_top or not is_instance_valid(player.active_ladder_area):
		return false
	var ladder_root: Node = player.active_ladder_area.get_parent()
	if not ladder_root.has_method("begin_top_drop") or not ladder_root.is_top_exit() or not ladder_root.has_method("get_exit_position"):
		return false
	return player.global_position.distance_to(ladder_root.get_exit_position()) <= 48.0

func state_ladder() -> void:
	if exit_animation_active:
		player._stop_ladder_sfx()
		player.velocity = Vector2.ZERO
		return
	if entry_time > 0.0:
		player._stop_ladder_sfx()
		player.velocity = Vector2.ZERO
		return
	player._reset_sprite_animation_speed()
	if waiting_for_area:
		if Global.is_climbing:
			waiting_for_area = false
			top_drop_time = 0.0
		else:
			player._play_ladder_sfx()
			player.velocity = Vector2(0, 45)
			return
	if top_drop_time > 0.0:
		player._play_ladder_sfx()
		player.velocity = Vector2(0, 45)
		return
	if side_return_active:
		player._stop_ladder_sfx()
		player.velocity = Vector2.ZERO
		return
	if not Input.is_action_pressed("left") and not Input.is_action_pressed("right") and side_pose != &"":
		side_pose = &""
		player._stop_ladder_sfx()
		player.velocity = Vector2.ZERO
		player._start_ladder_side_return()
		return

	if Input.is_action_pressed("up"):
		if Global.is_climbing:
			player.velocity.y = -30
			player.velocity.x = 0
			player._play_ladder_climbing_sprite()
			player._play_ladder_sfx()
		else:
			player._stop_ladder_sfx()
			exit_animation_active = true
			var exit_position: Vector2 = player.ladder_exit_position
			if exit_position == Vector2.ZERO:
				exit_position = player.global_position + Vector2(20.0, -5.0)
			player.velocity = Vector2.ZERO
			var tween: Tween = player.get_tree().create_tween()
			tween.tween_property(player, "global_position", exit_position, 0.9)
			player.animPlayer.stop()
			player.animPlayer.play("new_climbung_ledge_up")
			await player.animPlayer.animation_finished
			await tween.finished
			player._reset_sprite_animation_speed()
			player.ladder_exit_position = Vector2.ZERO
			player.hero_ladder = false
			player.state = player.ON_FLOOR
			player.apply_floor_snap()
			exit_animation_active = false

	elif Input.is_action_pressed("down"):
		if Global.is_climbing:
			if player.is_on_floor() and centering_time <= 0.0:
				player._stop_ladder_sfx()
				player.velocity = Vector2.ZERO
				player.hero_ladder = false
				player.state = player.ON_FLOOR
				return
			player.velocity.y = 30
			player.velocity.x = 0
			player._play_ladder_climbing_sprite()
			player._play_ladder_sfx()
		elif is_near_top_exit():
			begin_top_drop()
		else:
			player._stop_ladder_sfx()
			player.velocity = Vector2.ZERO
			player.hero_ladder = false
			player.state = player.ON_FLOOR

	elif Input.is_action_pressed("right") and player.velocity.y == 0:
		player._stop_ladder_sfx()
		player.anim.flip_h = false
		if side_is_blocked(1):
			if player.anim.animation != &"ladder_side_blocked" or not player.anim.is_playing():
				player.anim.play(&"ladder_side_blocked")
		else:
			_update_side_pose(1)

	elif Input.is_action_pressed("left") and player.velocity.y == 0:
		player._stop_ladder_sfx()
		player.anim.flip_h = true
		if side_is_blocked(-1):
			if player.anim.animation != &"ladder_side_blocked" or not player.anim.is_playing():
				player.anim.play(&"ladder_side_blocked")
		else:
			_update_side_pose(-1)

	elif Input.is_action_just_pressed("block"):
		player._stop_ladder_sfx()
		player.hero_ladder = false
		player.state = player.IN_AIR
	else:
		player._stop_ladder_sfx()
		player.velocity.y = 0
		player.velocity.x = 0
		if side_pose == &"":
			player._play_ladder_climbing_idle_sprite()

func _update_side_pose(direction: int) -> void:
	if side_pose == &"":
		side_pose = &"ladder_prepare_jump"
		player.animPlayer.stop()
		player.anim.play(side_pose)
	elif side_pose == &"ladder_prepare_jump" and not player.anim.is_playing():
		side_pose = &"ladder_prepare_jump_idle"
		player.anim.play(side_pose)
	elif side_pose == &"ladder_prepare_jump_idle" and not player.anim.is_playing():
		player.anim.play(side_pose)
	if Input.is_action_just_pressed("jump"):
		side_pose = &""
		player.hero_ladder = false
		player.velocity.y = -lerp(player.velocity.y, 650.0, 0.6)
		player.velocity.x = 170.0 * direction
		player.anim.flip_h = direction < 0
		player.raycast_up.target_position.x = 20.0 * direction
		player.raycast_hero_push_coll.target_position.x = 20.0 * direction
		player.raycast_down.target_position.x = 20.0 * direction
		player.raycast_hands_coll.target_position.x = 70.0 * direction
		player.get_node("AttackDirection").rotation_degrees = 0 if direction > 0 else 180
		player.state = player.IN_AIR
		player.animPlayer.play("jump_hands")
		await player.animPlayer.animation_finished
