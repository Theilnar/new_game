class_name LedgeController
extends RefCounted

## Decision layer for ledges and fences. Scene probing and animations stay in Player.

const PLAYER_COLLISION_BOTTOM_OFFSET: float = 25.0
const FENCE_THICKNESS: float = 15.0
const FENCE_PLAYER_WIDTH: float = 28.0
const FENCE_VAULT_DISTANCE: float = FENCE_THICKNESS + FENCE_PLAYER_WIDTH + 2.0
const FENCE_VAULT_UP_DURATION: float = 0.85
const FENCE_VAULT_CROSS_DURATION: float = 0.65
const FENCE_VAULT_DOWN_DURATION: float = 2.35 - FENCE_VAULT_UP_DURATION - FENCE_VAULT_CROSS_DURATION
const FENCE_VAULT_TOP_CLEARANCE: float = 4.0
const LEDGE_CLIMB_MOVE_MIN_DURATION: float = 0.18
const LEDGE_CLIMB_MOVE_SPEED_SCALE: float = 1.8
const LEDGE_CLIMB_FINAL_Y_OFFSET: float = 5.0
var player

func snap_to_edge() -> void:
	player.raycast_down.force_raycast_update()
	if not player.raycast_down.is_colliding():
		return
	var collision_x: float = player.raycast_down.get_collision_point().x
	var side: int = 1 if player.raycast_down.target_position.x > 0.0 else -1
	player.global_position.x = collision_x - 14.0 * float(side)

func has_floor_ahead(direction: float) -> bool:
	if is_zero_approx(direction):
		return true
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var sample_x: float = player.global_position.x + direction * 18.0
	var from_point := Vector2(sample_x, player.global_position.y + 16.0)
	var to_point := Vector2(sample_x, player.global_position.y + 42.0)
	var query := PhysicsRayQueryParameters2D.create(from_point, to_point, player.raycast_down.collision_mask)
	query.exclude = [player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	return normal.y < -0.5

func start_edge_recovery(direction: float) -> void:
	player.edge_recovery_active = true
	player.edge_recovery_elapsed = 0.0
	player.edge_recovery_direction = direction
	player.velocity.x = -direction * 100.0
	player.animPlayer.stop()
	if player.anim.sprite_frames.has_animation(&"ledge_prepare_drop_return"):
		player.anim.play(&"ledge_prepare_drop_return")
	else:
		player._play_idle_sprite()

func find_drop_target_y(direction: float) -> float:
	player.raycast_down.force_raycast_update()
	player.raycast_up.force_raycast_update()
	if not player.raycast_down.is_colliding():
		return NAN
	var edge_x: float = player.raycast_down.get_collision_point().x
	var platform_x: float = edge_x - direction * 4.0
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var from_point := Vector2(platform_x, player.global_position.y - 150.0)
	var to_point := Vector2(platform_x, player.global_position.y + 100.0)
	var query := PhysicsRayQueryParameters2D.create(from_point, to_point, player.raycast_down.collision_mask)
	query.exclude = [player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return NAN
	var collider := hit.get("collider") as Node
	if collider == null or (not collider.is_in_group("Platform") and not collider.is_in_group("Fence")):
		return NAN
	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	if normal.y > -0.5:
		return NAN
	return float(hit.get("position", Vector2.ZERO).y) - PLAYER_COLLISION_BOTTOM_OFFSET

func find_descent_edge_x(direction: float) -> Dictionary:
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var mask: int = player.raycast_down.collision_mask
	var scan_start: float = player.global_position.x - direction * 40.0
	var found_platform := false
	var last_platform_x: float = player.global_position.x
	for index in range(0, 101):
		var sample_x: float = scan_start + direction * float(index) * 2.0
		var from_point := Vector2(sample_x, player.global_position.y - 120.0)
		var to_point := Vector2(sample_x, player.global_position.y + 80.0)
		var query := PhysicsRayQueryParameters2D.create(from_point, to_point, mask)
		query.exclude = [player.get_rid()]
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit: Dictionary = space_state.intersect_ray(query)
		var collider := hit.get("collider") as Node if not hit.is_empty() else null
		var is_platform := collider != null and collider.is_in_group("Platform")
		if is_platform:
			found_platform = true
			last_platform_x = sample_x
		elif found_platform:
			var edge_x: float = last_platform_x + direction * 1.0
			return {"found": true, "x": edge_x - 14.0 * signf(direction)}
	return {"found": false, "x": player.global_position.x}

func find_fence_top_y(fallback_y: float) -> float:
	player.raycast_down.force_raycast_update()
	if not player.raycast_down.is_colliding():
		return fallback_y - PLAYER_COLLISION_BOTTOM_OFFSET - 8.0
	var fence_edge_x: float = player.raycast_down.get_collision_point().x
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	for offset in [4.0, 2.0, 0.0, -2.0, -4.0]:
		var sample_x: float = fence_edge_x + float(player.fence_wall_side) * offset
		var query := PhysicsRayQueryParameters2D.create(
			Vector2(sample_x, fallback_y - 220.0),
			Vector2(sample_x, fallback_y + 40.0),
			player.raycast_down.collision_mask
		)
		query.exclude = [player.get_rid()]
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit: Dictionary = space_state.intersect_ray(query)
		var collider: Node = hit.get("collider") as Node if not hit.is_empty() else null
		if collider != null and collider.is_in_group("Fence"):
			return float(hit.get("position", Vector2.ZERO).y)
	return fallback_y - PLAYER_COLLISION_BOTTOM_OFFSET - 8.0

func start_fence_vault() -> void:
	if player.fence_vault_active or not player.is_hanging_on_fence:
		return
	player.fence_vault_active = true
	player.climbing_lock = true
	player.state = player.ON_CLIMBING
	player.velocity = Vector2.ZERO
	player.animPlayer.stop()
	player.anim.play(&"fence_vault")
	player.fence_vault_saved_collision_layer = player.collision_layer
	player.fence_vault_saved_collision_mask = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0

	var start_position: Vector2 = player.global_position
	var vault_direction: float = float(player.fence_wall_side)
	player.raycast_down.target_position.x = vault_direction * (FENCE_VAULT_DISTANCE + FENCE_THICKNESS + 10.0)
	player.raycast_down.force_raycast_update()
	var fence_top_y: float = find_fence_top_y(start_position.y)
	var apex_y: float = fence_top_y - PLAYER_COLLISION_BOTTOM_OFFSET - FENCE_VAULT_TOP_CLEARANCE
	var target_position := Vector2(start_position.x + vault_direction * FENCE_VAULT_DISTANCE, start_position.y)
	apex_y = minf(apex_y, start_position.y - 8.0)

	player.fence_vault_tween = player.get_tree().create_tween()
	player.fence_vault_tween.set_parallel(false)
	player.fence_vault_tween.tween_property(player, "global_position:y", apex_y, FENCE_VAULT_UP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	player.fence_vault_tween.tween_property(player, "global_position:x", target_position.x, FENCE_VAULT_CROSS_DURATION).set_trans(Tween.TRANS_LINEAR)
	player.fence_vault_tween.tween_property(player, "global_position:y", target_position.y, FENCE_VAULT_DOWN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await player.fence_vault_tween.finished
	player.fence_vault_tween = null
	player.global_position = target_position
	player.collision_layer = player.fence_vault_saved_collision_layer
	player.collision_mask = player.fence_vault_saved_collision_mask
	player.fence_wall_side *= -1
	player.raycast_up.target_position.x = 20.0 * player.fence_wall_side
	player.raycast_down.target_position.x = 20.0 * player.fence_wall_side
	player.raycast_hands_coll.target_position.x = 70.0 * player.fence_wall_side
	player.raycast_hero_push_coll.target_position.x = 20.0 * player.fence_wall_side
	player.anim.flip_h = player.fence_wall_side < 0
	player.state = player.ON_WALL
	player.climbing_lock = false
	player.fence_vault_active = false

func climb() -> void:
	if player.ledge_return_animation_active and not player.is_hanging_on_pipe:
		player.velocity = Vector2.ZERO
		player.climb_on = true
		return
	if player.is_hanging_on_pipe:
		player._update_pipe_swing(player.get_physics_process_delta_time())
		player.velocity = Vector2.ZERO
		if player.animPlayer.is_playing():
			player.animPlayer.stop()
		if player.anim.animation != &"pipe_swing":
			player.anim.play(&"pipe_swing")
		player.climb_on = true
		return
	if player.is_hanging_on_bar:
		player.velocity = Vector2.ZERO
		player.climb_on = true
		var bar_direction: float = Input.get_axis("left", "right")
		if not is_zero_approx(bar_direction):
			player.global_position.x = clampf(player.global_position.x + bar_direction * 35.0 * player.get_physics_process_delta_time(), player.bar_left_limit, player.bar_right_limit)
			var at_left_edge: bool = player.global_position.x <= player.bar_left_limit + 3.0
			var at_right_edge: bool = player.global_position.x >= player.bar_right_limit - 3.0
			if bar_direction < 0.0 and at_left_edge:
				player.anim.flip_h = true
				player.anim.play(&"bar_prepare_jump_left")
			elif bar_direction > 0.0 and at_right_edge:
				player.anim.flip_h = false
				player.anim.play(&"bar_prepare_jump_right")
			elif bar_direction < 0.0:
				player.anim.flip_h = true
				player.anim.play(&"bar_move")
			else:
				player.anim.flip_h = false
				player.anim.play(&"bar_move")
		elif player.anim.animation != &"bar_hang":
			player.anim.play(&"bar_hang")
		return

	if player.is_hanging_on_fence:
		player.velocity = Vector2.ZERO
		player.ledge_testing = true
		player.anim.flip_h = player.fence_wall_side < 0
		if (player.fence_wall_side > 0 and Input.is_action_just_pressed("right")) or (player.fence_wall_side < 0 and Input.is_action_just_pressed("left")):
			await start_fence_vault()
			return
		var fence_pose: StringName = &""
		var side_pressed: bool = Input.is_action_pressed("left") or Input.is_action_pressed("right")
		if player.ledge_pose != &"" and side_pressed and Input.is_action_pressed("down"):
			fence_pose = player.ledge_pose
		elif side_pressed and not player.side_input_was_held_on_ledge_grab:
			fence_pose = &"wall_hands_forward"
		elif Input.is_action_pressed("down") and not side_pressed:
			fence_pose = &"ledge_prepare_drop"
		if fence_pose != &"":
			if player.ledge_pose != fence_pose:
				player.ledge_pose = fence_pose
				player.animPlayer.stop()
				player.anim.play(player.ledge_pose)
			elif player.ledge_pose == &"ledge_prepare_drop" and not player.anim.is_playing():
				player.anim.play(&"ledge_prepare_drop_idle")
			elif player.ledge_pose == &"wall_hands_forward" and not player.anim.is_playing():
				player.anim.play(&"wall_hands_forward_idle")
		elif player.ledge_pose != &"":
			var return_animation: StringName = &"ledge_prepare_drop_return"
			if player.ledge_pose == &"wall_hands_forward":
				return_animation = &"wall_hands_forward_return"
			player.ledge_pose = &""
			player.animPlayer.stop()
			player._start_ledge_return_animation(return_animation)
		elif player.anim.animation != &"fence_grab":
			player.anim.play(&"fence_grab")
		player.climb_on = true
		if not Input.is_action_pressed("left") and not Input.is_action_pressed("right"):
			player.side_input_was_held_on_ledge_grab = false
		return

	if Input.is_action_pressed("up"):
		player.state = player.ON_CLIMBING
		await climbing_up()
		if player.climbing_lock:
			return
	player.velocity.x = 0.0
	player.ledge_testing = true
	if player.raycast_up.target_position.x == -20:
		player.anim.flip_h = true
	elif player.raycast_up.target_position.x == 20:
		player.anim.flip_h = false
	var wanted_pose: StringName = &""
	var side_pressed: bool = Input.is_action_pressed("left") or Input.is_action_pressed("right")
	if player.ledge_pose != &"" and side_pressed and Input.is_action_pressed("down"):
		wanted_pose = player.ledge_pose
	elif side_pressed and not player.side_input_was_held_on_ledge_grab and ((player.raycast_up.target_position.x == -20 and Input.is_action_pressed("right")) or (player.raycast_up.target_position.x == 20 and Input.is_action_pressed("left"))):
		wanted_pose = &"wall_hands_forward"
	elif Input.is_action_pressed("down") and not side_pressed:
		wanted_pose = &"ledge_prepare_drop"
	if wanted_pose != &"":
		if player.ledge_pose != wanted_pose:
			player.ledge_pose = wanted_pose
			player.animPlayer.stop()
			player.anim.play(player.ledge_pose)
		elif player.ledge_pose == &"ledge_prepare_drop" and not player.anim.is_playing():
			player.anim.play(&"ledge_prepare_drop_idle")
		elif player.ledge_pose == &"wall_hands_forward" and not player.anim.is_playing():
			player.anim.play(&"wall_hands_forward_idle")
	else:
		if player.ledge_pose != &"":
			var return_animation: StringName = &"ledge_prepare_drop_return"
			if player.ledge_pose == &"wall_hands_forward":
				return_animation = &"wall_hands_forward_return"
			player.ledge_pose = &""
			player.animPlayer.stop()
			player._start_ledge_return_animation(return_animation)
		elif player.animPlayer.current_animation != &"climbing":
			player.animPlayer.play("climbing")
	player.climb_on = true
	if not Input.is_action_pressed("left") and not Input.is_action_pressed("right"):
		player.side_input_was_held_on_ledge_grab = false

func climbing_up() -> void:
	if player.climbing_lock:
		return
	if player.is_hanging_on_fence:
		if Input.is_action_just_pressed("up") or (player.fence_wall_side > 0 and Input.is_action_just_pressed("right")) or (player.fence_wall_side < 0 and Input.is_action_just_pressed("left")):
			await start_fence_vault()
		return

	player.climb_on = false
	player._play_climb_sfx()
	var climb_direction: int = 0
	if player.raycast_up.target_position.x == 20 and Input.is_action_just_pressed("up"):
		climb_direction = 1
	elif player.raycast_up.target_position.x == -20 and Input.is_action_pressed("up"):
		climb_direction = -1
	else:
		return

	player.climbing_lock = true
	player.state = player.ON_CLIMBING
	player.velocity = Vector2.ZERO
	player._play_climb_sfx()
	player.animPlayer.stop()
	player.anim.stop()
	player.anim.play(&"new_ledge_climbing")
	var frame_count: int = player.anim.sprite_frames.get_frame_count(&"new_ledge_climbing")
	var fps: float = player.anim.sprite_frames.get_animation_speed(&"new_ledge_climbing")
	var climb_duration: float = maxf(LEDGE_CLIMB_MOVE_MIN_DURATION, float(frame_count) / maxf(fps * LEDGE_CLIMB_MOVE_SPEED_SCALE, 1.0))
	var finish_tween: Tween = player.get_tree().create_tween()
	var target_x: float = player.ledge_right_posx if climb_direction > 0 else player.ledge_left_posx
	var target_y: float = player.ledge_right_posy if climb_direction > 0 else player.ledge_left_posy
	finish_tween.tween_property(player, "global_position:y", target_y + LEDGE_CLIMB_FINAL_Y_OFFSET, climb_duration * 0.6)
	finish_tween.tween_property(player, "global_position:x", target_x, climb_duration * 0.34)
	await finish_tween.finished
	player.anim.stop()
	player.state = player.ON_FLOOR
	player.anim.flip_h = climb_direction < 0
	player.turn_around_left = climb_direction < 0
	player.turn_around_right = climb_direction > 0
	player.is_on_ledge_down = false
	player.is_on_ledge_up = false
	player.wall_contact_active = false
	player.velocity = Vector2.ZERO
	player.climbing_lock = false
	player._update_body_render_mode()

func can_grab(current_state: int, lock_time: float, is_airborne: bool, is_strong_fall_animating: bool) -> bool:
	return (is_airborne or (current_state == 14 and not is_strong_fall_animating)) and lock_time <= 0.0

func pose_for_input(has_side_input: bool, wants_drop: bool, previous_pose: StringName, side_was_held: bool, facing_wall: bool) -> StringName:
	if previous_pose != &"" and has_side_input and wants_drop:
		return previous_pose
	if has_side_input and not side_was_held and facing_wall:
		return &"wall_hands_forward"
	if wants_drop and not has_side_input:
		return &"ledge_prepare_drop"
	return &""
