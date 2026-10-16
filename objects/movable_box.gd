extends Node2D

@export var move_limit_left: float = -240.0
@export var move_limit_right: float = 240.0

var box_move_x: float = 0.0

func _ready() -> void:
	Signals.connect("box_push", _on_box_push)

func _physics_process(_delta: float) -> void:
	# The player enters push_mode only after pressing F. Therefore the box
	# never moves just because the player is touching it.
	if Global.box_player_collision and Global.push_onoff and not is_zero_approx(box_move_x):
		position.x = clampf(position.x + box_move_x, move_limit_left, move_limit_right)

func _on_box_push(value: float) -> void:
	box_move_x = value

func _on_left_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Static_body_item"):
		Global.player_pushbox_left = false

func _on_left_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("Static_body_item"):
		Global.player_pushbox_left = true

func _on_right_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Static_body_item"):
		Global.player_pushbox_right = true

func _on_right_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("Static_body_item"):
		Global.player_pushbox_right = false

func _on_player_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		Global.box_player_collision = true

func _on_player_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		Global.box_player_collision = false
