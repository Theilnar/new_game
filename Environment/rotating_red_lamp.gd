extends Node2D
class_name RotatingRedLamp

@export var rotation_speed: float = 2.4
@export var rotate_clockwise: bool = true
@export var light_energy_pulse: float = 0.12
@export var light_pulse_speed: float = 5.0

@onready var rotating_head: Node2D = $RotatingHead
@onready var red_light: PointLight2D = $RotatingHead/RedLight
@onready var motor_sound: AudioStreamPlayer2D = $MotorSound

var pulse_time: float = 0.0

func _ready() -> void:
	if motor_sound.stream != null:
		motor_sound.finished.connect(_on_motor_sound_finished)
		motor_sound.play()

func _process(delta: float) -> void:
	var direction := 1.0 if rotate_clockwise else -1.0
	rotating_head.rotation += rotation_speed * direction * delta

	pulse_time += delta * light_pulse_speed
	red_light.energy = 2.8 + sin(pulse_time) * light_energy_pulse

func _on_motor_sound_finished() -> void:
	if is_inside_tree() and motor_sound.stream != null:
		motor_sound.play()
