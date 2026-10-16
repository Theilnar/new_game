extends Area2D

enum AnomalyMode { VORTEX, SPRINGBOARD }

@export var mode: AnomalyMode = AnomalyMode.VORTEX
@export var lethal_damage: int = 1000
@export var springboard_damage: int = 35
@export var pull_time: float = 0.42
@export var springboard_force: float = 850.0
@export var collapse_time: float = 0.35
@export var respawn_delay: float = 5.0

@onready var visual: Sprite2D = $Visual
@onready var core: Sprite2D = $Core
@onready var particles: GPUParticles2D = $DustParticles
@onready var ambient_sound: AudioStreamPlayer2D = $AmbientSound
@onready var hit_sound: AudioStreamPlayer2D = $HitSound
@onready var collapse_sound: AudioStreamPlayer2D = $CollapseSound
@onready var appear_sound: AudioStreamPlayer2D = $AppearSound

var triggered := false
var respawning := false
const VISUAL_SCALE := Vector2(1.35, 1.35)
const CORE_SCALE := Vector2(0.52, 0.52)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	ambient_sound.finished.connect(_on_ambient_finished)
	ambient_sound.play()


func _on_ambient_finished() -> void:
	if not respawning and not triggered:
		ambient_sound.play()


func _process(delta: float) -> void:
	visual.rotation += delta * 0.35
	core.rotation -= delta * 0.8
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.035
	visual.scale = VISUAL_SCALE * pulse


func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	if body.is_in_group("projectile") or body.name == "Bullet":
		hit_sound.play()
		body.queue_free()
		collapse()
		return
	if body.name == "Player" or body.is_in_group("player"):
		trigger_player(body)


func _on_area_entered(area: Area2D) -> void:
	if triggered:
		return
	if area.is_in_group("projectile") or area.name == "Bullet":
		hit_sound.play()
		area.queue_free()
		collapse()


func trigger_player(player: Node2D) -> void:
	if triggered:
		return
	triggered = true
	set_deferred("monitoring", false)

	if mode == AnomalyMode.SPRINGBOARD:
		if player is CharacterBody2D:
			player.velocity = Vector2(0.0, -springboard_force)
		Signals.emit_signal("enemy_attack", springboard_damage)
		collapse()
		return

	# Temporarily pull the player to the center before applying the impact.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(player, "global_position", global_position, pull_time)
	await tween.finished
	if is_instance_valid(player):
		Signals.emit_signal("enemy_attack", lethal_damage)
	collapse()


func collapse() -> void:
	if not is_instance_valid(self):
		return
	if respawning:
		return
	triggered = true
	respawning = true
	set_deferred("monitoring", false)
	particles.emitting = false
	ambient_sound.stop()
	collapse_sound.play()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2.ZERO, collapse_time)
	tween.tween_property(core, "scale", Vector2.ZERO, collapse_time)
	tween.tween_property(self, "modulate:a", 0.0, collapse_time)
	await tween.finished

	await get_tree().create_timer(respawn_delay).timeout
	if not is_instance_valid(self):
		return

	visual.scale = Vector2.ZERO
	core.scale = Vector2.ZERO
	modulate.a = 0.0
	visible = true
	particles.emitting = true
	particles.restart()
	appear_sound.play()
	ambient_sound.play()

	var respawn_tween := create_tween()
	respawn_tween.set_parallel(true)
	respawn_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	respawn_tween.tween_property(visual, "scale", VISUAL_SCALE, 0.7)
	respawn_tween.tween_property(core, "scale", CORE_SCALE, 0.7)
	respawn_tween.tween_property(self, "modulate:a", 1.0, 0.55)
	await respawn_tween.finished
	triggered = false
	respawning = false
	set_deferred("monitoring", true)
