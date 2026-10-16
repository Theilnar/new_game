extends Node2D

@onready var light = $DirectionalLight2D
#@onready var pointlight = $PointLight2D
@onready var day_text = $"../CanvasLayer/Start_text"
@onready var animPlay = $"../CanvasLayer/AnimationPlayer"
@onready var healthbar = $"../CanvasLayer/health_bar"
@onready var staminabar = $"../CanvasLayer/stamina_bar"
@onready var player = $"../Player/Player"

var day = 1
enum {
	MORNING,
	DAY,
	EVENING,
	NIGHT
}
var state = MORNING

func _ready() -> void:
	#light.enabled = true  #включать здесь
	day_text_fade()
	healthbar.max_value = player.max_health
	healthbar.value = healthbar.max_value
	staminabar.max_value = player.max_stamina
	staminabar.value = player.stamina
	player.stamina_changed.connect(_on_player_stamina_changed)

func _on_player_stamina_changed(value: float) -> void:
	staminabar.value = value
	
func _process(_delta: float) -> void:
	start_text()
			
func morning_state():
	var tween = get_tree().create_tween()
	tween.tween_property(light, "energy", 0.5, 20)
func evening_state():
	var tween = get_tree().create_tween()
	tween.tween_property(light, "energy", 6.0, 20)

func _on_day_night_timeout() -> void:
	match state:
		MORNING:
			morning_state()
		EVENING:
			evening_state()
	if state < 4:
		state += 1.0
	else:
		day +=1
		state = MORNING
		start_text()
		day_text_fade()

func day_text_fade():
	
	animPlay.play('start_text_fade_in')
	await get_tree().create_timer(3).timeout
	animPlay.play('start_text_fade_out')		
		
func start_text():
	day_text.text = ('DAY: '+str(day))


func _on_player_health_changed(new_health: Variant) -> void:
	healthbar.value = new_health
