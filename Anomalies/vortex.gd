extends Area2D

enum AnomalyMode { VORTEX, SPRINGBOARD }

@export var mode: AnomalyMode = AnomalyMode.VORTEX
@export var lethal_damage: int = 1000
@export var springboard_damage: int = 35
@export var pull_time: float = 0.42
@export var springboard_force: float = 850.0
@export var collapse_time: float = 0.35

@onready var visual: Sprite2D = $Visual
@onready var core: Sprite2D = $Core

var triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	visual.rotation += delta * 0.35
	core.rotation -= delta * 0.8
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.035
	visual.scale = Vector2.ONE * pulse


func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	if body.is_in_group("projectile") or body.name == "Bullet":
		body.queue_free()
		collapse()
		return
	if body.name == "Player" or body.is_in_group("player"):
		trigger_player(body)


func _on_area_entered(area: Area2D) -> void:
	if triggered:
		return
	if area.is_in_group("projectile") or area.name == "Bullet":
		area.queue_free()
		collapse()


func trigger_player(player: Node2D) -> void:
	if triggered:
		return
	triggered = true
	monitoring = false

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
	triggered = true
	monitoring = false

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2.ZERO, collapse_time)
	tween.tween_property(core, "scale", Vector2.ZERO, collapse_time)
	tween.tween_property(self, "modulate:a", 0.0, collapse_time)
	await tween.finished
	queue_free()
