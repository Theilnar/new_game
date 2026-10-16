extends StaticBody2D

@export var bar_length: float = 220.0
@export var bar_thickness: float = 8.0

@onready var grab_area: Area2D = $GrabArea

func _ready() -> void:
	grab_area.body_entered.connect(_on_grab_area_body_entered)

func _on_grab_area_body_entered(body: Node2D) -> void:
	if body.has_method("_grab_hanging_bar"):
		body._grab_hanging_bar(self)

func get_grab_position() -> Vector2:
	return global_position

func get_left_limit() -> float:
	return global_position.x - bar_length * 0.5

func get_right_limit() -> float:
	return global_position.x + bar_length * 0.5
