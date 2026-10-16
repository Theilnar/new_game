extends Area2D

@export_category("Chemical Damage")
@export var damage: int = 18
@export var damage_cooldown: float = 1.0

@export_category("Puddle")
@export var puddle_scale := Vector2(1.45, 0.58)
@export var boil_speed: float = 1.8

@onready var puddle: Sprite2D = $Puddle
@onready var steam: GPUParticles2D = $Steam
@onready var bubbles: GPUParticles2D = $Bubbles
@onready var ambient_sound: AudioStreamPlayer2D = $AmbientSound

var player_inside: Node2D
var damage_timer := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	ambient_sound.finished.connect(_on_ambient_finished)
	puddle.scale = puddle_scale
	var material := puddle.material as ShaderMaterial
	if material:
		material.set_shader_parameter("wave_speed", boil_speed)
	ambient_sound.play()


func _process(delta: float) -> void:
	damage_timer = maxf(0.0, damage_timer - delta)
	if is_instance_valid(player_inside) and damage_timer <= 0.0:
		damage_timer = damage_cooldown
		Signals.emit_signal("enemy_attack", damage)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_inside = body


func _on_body_exited(body: Node2D) -> void:
	if body == player_inside:
		player_inside = null


func _on_ambient_finished() -> void:
	ambient_sound.play()
