extends Node2D

## Универсальная зона комнаты с туманом и дверью.
## Размещается вручную на уровне как FogRoomZone.tscn.

@export var player_path: NodePath = NodePath("../Player/Player")
@export var interaction_action := "interact"
@export var fade_speed := 2.0
@export_range(0.0, 1.0, 0.01) var closed_fog_alpha := 1.0

var _player_inside_interaction := false
var _player_inside_room := false
var _door_open := false
var _door_animating := false
var _fog_alpha := 1.0

@onready var _fog_overlay: Polygon2D = $FogOverlay
@onready var _door_body: StaticBody2D = $DoorBody
@onready var _interaction_area: Area2D = $InteractionArea
@onready var _room_area: Area2D = $RoomArea
@onready var _interact_prompt: Label = $InteractPrompt
@onready var _door_sprite: AnimatedSprite2D = $DoorAnimatedSprite
@onready var _door_open_sound: AudioStreamPlayer2D = $DoorOpenSound

func _ready() -> void:
	# Начальное состояние: дверь закрыта на первом кадре.
	_door_sprite.stop()
	_door_sprite.animation = &"open"
	_door_sprite.frame = 0
	_interaction_area.body_entered.connect(_on_interaction_body_entered)
	_interaction_area.body_exited.connect(_on_interaction_body_exited)
	_room_area.body_entered.connect(_on_room_body_entered)
	_room_area.body_exited.connect(_on_room_body_exited)
	_update_fog()

func _process(delta: float) -> void:
	if not _door_open and not _door_animating and _player_inside_interaction and Input.is_action_just_pressed(interaction_action):
		_open_door()

	var target_alpha := 0.0 if _door_open and _player_inside_room else closed_fog_alpha
	_fog_alpha = move_toward(_fog_alpha, target_alpha, fade_speed * delta)
	_update_fog()

func _open_door() -> void:
	if _door_open or _door_animating:
		return
	_door_animating = true
	_interact_prompt.visible = false
	_door_body.set_deferred("collision_layer", 0)
	_door_body.set_deferred("collision_mask", 0)
	_door_sprite.frame = 0
	_door_sprite.play(&"open")
	if _door_open_sound.stream != null:
		_door_open_sound.play()
	await _door_sprite.animation_finished
	# stop() сбрасывает AnimatedSprite2D на первый кадр, поэтому
	# сначала останавливаем, а затем снова фиксируем последний кадр.
	_door_sprite.stop()
	_door_sprite.frame = _door_sprite.sprite_frames.get_frame_count(&"open") - 1
	_door_sprite.frame_progress = 1.0
	_door_open = true
	_door_animating = false

func _update_fog() -> void:
	if is_instance_valid(_fog_overlay):
		_fog_overlay.color = Color(0.03, 0.03, 0.03, _fog_alpha)

func _on_interaction_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_inside_interaction = true
		_interact_prompt.visible = not _door_open

func _on_interaction_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_inside_interaction = false
		_interact_prompt.visible = false

func _on_room_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_inside_room = true

func _on_room_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_inside_room = false

func _is_player(body: Node) -> bool:
	var player := get_node_or_null(player_path)
	return body == player or (player != null and player.is_ancestor_of(body))
