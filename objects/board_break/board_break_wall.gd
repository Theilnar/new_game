class_name BoardBreakWall
extends Node2D

@export var hold_duration := 3.0
@export var interaction_action: StringName = &"interact"
@export var grab_animation: StringName = &"board_break_grab"
@export var hold_animation: StringName = &"board_break_hold"
@export var tear_animation: StringName = &"board_break_tear"
@export var player_recoil := 34.0
@export var chunk_scene: PackedScene = preload("res://objects/board_break/BoardChunk.tscn")

@export_category("Sound")
@export var hold_sound: AudioStream
@export var tear_sound: AudioStream

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt: Label = $Prompt
@onready var progress_label: Label = $Progress
@onready var wall_collision: CollisionShape2D = $WallCollision/CollisionShape2D
@onready var boards: Node2D = $Boards
@onready var hold_audio: AudioStreamPlayer2D = $HoldAudio
@onready var tear_audio: AudioStreamPlayer2D = $TearAudio

var nearby_player: CharacterBody2D
var breaking := false
var grab_finished := false
var hold_time := 0.0
var board_index := 0
var saved_collision_layer := 0
var saved_collision_mask := 0

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	prompt.visible = false
	progress_label.visible = false
	hold_audio.stream = hold_sound
	tear_audio.stream = tear_sound

func _process(delta: float) -> void:
	if not is_instance_valid(nearby_player):
		nearby_player = null
		if breaking:
			_cancel_break()

	if not breaking:
		prompt.visible = nearby_player != null and board_index < boards.get_child_count()
		return

	if not Input.is_action_pressed(interaction_action):
		_cancel_break()
		return

	if not grab_finished:
		return

	if hold_sound != null and not hold_audio.playing:
		hold_audio.play()
	hold_time = minf(hold_time + delta, hold_duration)
	_update_hold_animation()
	progress_label.text = "%d%%" % roundi(hold_time / hold_duration * 100.0)
	if hold_time >= hold_duration:
		_finish_break()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(interaction_action) and nearby_player != null and not breaking and board_index < boards.get_child_count():
		_start_break()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body is CharacterBody2D:
		nearby_player = body

func _on_body_exited(body: Node2D) -> void:
	if body == nearby_player and not breaking:
		nearby_player = null

func _start_break() -> void:
	if not is_instance_valid(nearby_player):
		return
	breaking = true
	grab_finished = false
	hold_time = 0.0
	prompt.visible = false
	progress_label.visible = true
	progress_label.text = "0%"
	_lock_player()
	_play_player_animation(grab_animation)
	await get_tree().create_timer(0.35).timeout
	if breaking and is_instance_valid(nearby_player):
		grab_finished = true
		_play_player_animation(hold_animation)

func _update_hold_animation() -> void:
	if not is_instance_valid(nearby_player):
		return
	var sprite: AnimatedSprite2D = nearby_player.get_node_or_null("AnimatedSprite2D")
	if sprite == null or not sprite.sprite_frames.has_animation(hold_animation):
		return
	if sprite.animation != hold_animation:
		sprite.play(hold_animation)
	var frame_count := sprite.sprite_frames.get_frame_count(hold_animation)
	if frame_count > 1:
		sprite.pause()
		sprite.frame = mini(int((hold_time / hold_duration) * frame_count), frame_count - 1)

func _finish_break() -> void:
	grab_finished = false
	progress_label.visible = false
	_play_player_animation(tear_animation)
	_spawn_chunk()
	_remove_board()
	_stop_hold_sound()
	if tear_sound != null:
		tear_audio.play()
	_apply_recoil()
	# Keep the player locked until the pull-off animation has actually played.
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(nearby_player):
		breaking = false
		return
	_unlock_player()
	breaking = false
	if board_index >= boards.get_child_count():
		wall_collision.set_deferred("disabled", true)

func _remove_board() -> void:
	if board_index >= boards.get_child_count():
		return
	boards.get_child(board_index).queue_free()
	board_index += 1

func _spawn_chunk() -> void:
	var chunk := chunk_scene.instantiate() as RigidBody2D
	get_tree().current_scene.add_child(chunk)
	chunk.global_position = global_position + Vector2(0, -18 + board_index * 22)
	var direction := 1.0 if not is_instance_valid(nearby_player) or nearby_player.global_position.x < global_position.x else -1.0
	chunk.apply_central_impulse(Vector2(direction * 150.0, -110.0))
	chunk.apply_torque_impulse(direction * 12.0)

func _lock_player() -> void:
	if not is_instance_valid(nearby_player):
		return
	saved_collision_layer = nearby_player.collision_layer
	saved_collision_mask = nearby_player.collision_mask
	nearby_player.collision_layer = 0
	nearby_player.collision_mask = 0
	nearby_player.velocity = Vector2.ZERO
	nearby_player.state = nearby_player.ON_CLIMB_BOX
	nearby_player.animPlayer.stop()
	# In the player scene flip_h=false means facing right.
	# Face the wall: a player on the left looks right, on the right looks left.
	var face_left := nearby_player.global_position.x > global_position.x
	nearby_player.anim.flip_h = face_left
	nearby_player.dir_look = not face_left

func _unlock_player() -> void:
	if not is_instance_valid(nearby_player):
		return
	nearby_player.collision_layer = saved_collision_layer
	nearby_player.collision_mask = saved_collision_mask
	nearby_player.state = nearby_player.ON_FLOOR
	nearby_player.velocity = Vector2.ZERO
	nearby_player._play_idle_sprite()

func _apply_recoil() -> void:
	if not is_instance_valid(nearby_player):
		return
	var direction := -1.0 if nearby_player.global_position.x < global_position.x else 1.0
	nearby_player.velocity.x = direction * player_recoil
	nearby_player.move_and_slide()
	nearby_player.velocity = Vector2.ZERO

func _cancel_break() -> void:
	if not breaking:
		return
	breaking = false
	grab_finished = false
	hold_time = 0.0
	progress_label.visible = false
	_stop_hold_sound()
	_unlock_player()

func _stop_hold_sound() -> void:
	if hold_audio.playing:
		hold_audio.stop()

func _play_player_animation(animation_name: StringName) -> void:
	if not is_instance_valid(nearby_player):
		return
	if nearby_player.anim.sprite_frames.has_animation(animation_name):
		nearby_player.animPlayer.stop()
		nearby_player.anim.play(animation_name)
