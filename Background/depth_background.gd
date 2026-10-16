extends Node2D
## Optional 2.5D rear background.
## This scene is deliberately isolated from gameplay: it has no physics,
## navigation, or references to the player. It can be removed/disabled safely.

@export var enabled := true

func _ready() -> void:
	visible = enabled

