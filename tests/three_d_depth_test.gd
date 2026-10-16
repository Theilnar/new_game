extends Node3D
## Isolated 2.5D/3D depth prototype. Not referenced by the main game.

@export var enemy_speed := 1.15
@export var enemy_left_limit := -4.2
@export var enemy_right_limit := 4.2
@onready var background_enemy: Sprite3D = $Layers/BackgroundEnemy
var enemy_direction := 1.0

func _process(delta: float) -> void:
	background_enemy.position.x += enemy_direction * enemy_speed * delta
	if background_enemy.position.x >= enemy_right_limit:
		background_enemy.position.x = enemy_right_limit
		enemy_direction = -1.0
		background_enemy.flip_h = true
	elif background_enemy.position.x <= enemy_left_limit:
		background_enemy.position.x = enemy_left_limit
		enemy_direction = 1.0
		background_enemy.flip_h = false
