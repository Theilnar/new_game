class_name CarryController
extends RefCounted

## Complete climb-box feature controller.
## Player remains the public compatibility facade because ClimbBox calls these
## methods on the player instance.

var player
var active_box: Node2D
var look_left: bool = false
var saved_collision_layer: int = 0
var saved_collision_mask: int = 0
var drop_active: bool = false

func is_active() -> bool:
	return is_instance_valid(active_box)

func animation_for_direction(direction: float) -> StringName:
	if is_zero_approx(direction):
		return &"hero_push_idle"
	if look_left:
		return &"push" if direction < 0.0 else &"pull"
	return &"pull" if direction < 0.0 else &"push"

func play_animation(mode: StringName) -> void:
	var animation_name: StringName = &"hero_push_idle"
	if mode == &"push":
		animation_name = &"push"
	elif mode == &"pull":
		animation_name = &"pull"
	if not player.anim.sprite_frames.has_animation(animation_name):
		return
	if player.animPlayer.is_playing():
		player.animPlayer.stop()
	if player.anim.animation != animation_name or not player.anim.is_playing():
		player.anim.play(animation_name)

func begin(box: Node2D, _carry_side: float) -> void:
	if active_box != null:
		return
	active_box = box
	var grab_y: float = player.global_position.y
	look_left = not player.dir_look
	saved_collision_layer = player.collision_layer
	saved_collision_mask = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector2.ZERO
	player.state = player.ON_CLIMB_BOX
	player.animPlayer.stop()
	player.anim.flip_h = look_left
	if player.anim.sprite_frames.has_animation(&"climb_box_grab"):
		player.anim.play(&"climb_box_grab")
	else:
		play_animation(&"hero_push_idle")
	var grab_tween: Tween = player.get_tree().create_tween()
	grab_tween.tween_property(player, "global_position:x", box.global_position.x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await grab_tween.finished
	player.global_position.y = grab_y
	play_animation(&"hero_push_idle")

func set_direction(direction: float) -> void:
	if player.state != player.ON_CLIMB_BOX or is_zero_approx(direction):
		return
	player.anim.flip_h = look_left
	play_animation(animation_for_direction(direction))

func release() -> void:
	if active_box == null:
		return
	player.collision_layer = saved_collision_layer
	player.collision_mask = saved_collision_mask
	clear()
	player.state = player.ON_FLOOR
	player.climb_box_top_lock_frames = 4
	player.floor_snap_length = 24.0
	player.velocity = Vector2(0.0, 12.0)
	player.move_and_slide()
	player.velocity = Vector2.ZERO
	player._play_idle_sprite()

func climb_to_top(box: Node2D, target_position: Vector2) -> void:
	if active_box != box:
		return
	player.animPlayer.stop()
	player.anim.flip_h = look_left
	if player.anim.sprite_frames.has_animation(&"climb_box_up"):
		player.anim.play(&"climb_box_up")
	else:
		player.anim.play(&"new_ledge_climbing")
	var climb_tween: Tween = player.get_tree().create_tween()
	climb_tween.tween_property(player, "global_position", target_position, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await climb_tween.finished
	release()

func descend(target_y: float) -> void:
	if drop_active:
		return
	drop_active = true
	player.state = player.ON_CLIMB_BOX
	player.velocity = Vector2.ZERO
	player.animPlayer.stop()
	player.anim.stop()
	var saved_layer: int = player.collision_layer
	var saved_mask: int = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0
	var drop_tween: Tween = player.get_tree().create_tween()
	drop_tween.tween_property(player, "global_position:y", target_y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop_tween.finished
	player.collision_layer = saved_layer
	player.collision_mask = saved_mask
	player.global_position.y = target_y
	player.velocity = Vector2.ZERO
	player.state = player.ON_FLOOR
	player.climb_box_top_lock_frames = 4
	player.floor_snap_length = 24.0
	player.apply_floor_snap()
	player._play_idle_sprite()
	drop_active = false

func clear() -> void:
	active_box = null
	drop_active = false
