extends Node2D

@export_category("Grass Variants")
@export var grass_textures: Array[Texture2D] = []
@export var randomize_appearance := true
@export_range(0.0, 0.25) var scale_variation := 0.08
@export_range(0.0, 0.2) var color_variation := 0.04

@export var interaction_radius := 48.0
@export var interaction_strength := 0.18
@export var wind_strength := 0.04
@export var sway_spring_strength := 30.0
@export var sway_damping := 6.0
@export var sway_impulse_multiplier := 4.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D

var player: Node2D
var current_push := 0.0
var current_direction := 0.0
var sway_offset := 0.0
var sway_velocity := 0.0
var was_interacting := false

func _ready() -> void:
	if not grass_textures.is_empty():
		sprite.texture = grass_textures.pick_random()
	if randomize_appearance:
		sprite.scale *= randf_range(1.0 - scale_variation, 1.0 + scale_variation)
		var tint := randf_range(1.0 - color_variation, 1.0 + color_variation)
		sprite.modulate = Color(tint, tint, tint, 1.0)
	# Each grass instance needs its own parameters; otherwise all copies share one material.
	sprite.material = sprite.material.duplicate()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player = players[0]

	var interaction_direction := 0.0
	var interacting := false
	if is_instance_valid(player):
		var offset := player.global_position - global_position
		var distance := absf(offset.x)
		var inside := distance <= interaction_radius and absf(offset.y) <= 46.0
		var velocity_value = player.get("velocity")
		var moving := velocity_value is Vector2 and absf(velocity_value.x) > 2.0
		if inside and moving:
			interacting = true
			interaction_direction = signf(velocity_value.x)

	if interacting and not was_interacting:
		sway_velocity += interaction_direction * interaction_strength * sway_impulse_multiplier
	was_interacting = interacting

	# Пружина возвращает траву через несколько затухающих колебаний,
	# вместо мгновенного lerp обратно в исходную позицию.
	var sway_acceleration := -sway_offset * sway_spring_strength - sway_velocity * sway_damping
	sway_velocity += sway_acceleration * _delta
	sway_offset += sway_velocity * _delta
	sway_offset = clampf(sway_offset, -interaction_strength, interaction_strength)
	current_push = absf(sway_offset)
	current_direction = signf(sway_offset) if not is_zero_approx(sway_offset) else 0.0
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter("windStrength", wind_strength)
	material.set_shader_parameter("interactionDirection", current_direction)
	material.set_shader_parameter("interactionBend", current_push)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
