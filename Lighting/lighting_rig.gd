extends Node2D

@export_category("Night")
@export var darkness_color := Color(0.18, 0.20, 0.25, 1.0)

@export_category("Glow")
@export var glow_enabled := true
@export_range(0.0, 4.0, 0.05) var glow_intensity := 0.75
@export_range(0.0, 4.0, 0.05) var glow_strength := 0.7

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	canvas_modulate.color = darkness_color
	if environment.environment:
		environment.environment.glow_enabled = glow_enabled
		environment.environment.glow_intensity = glow_intensity
		environment.environment.glow_strength = glow_strength
