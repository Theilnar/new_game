extends Area2D

const SOFT_DOT_TEXTURE := preload("res://Sprites/Light/circle_051.png")

@export_category("Damage")
@export var damage: int = 45
@export var damage_cooldown: float = 0.7

@export_category("Lightning")
@export var bolt_count: int = 0
@export var radius: float = 52.0
@export var refresh_rate: float = 0.12
@export var glow_energy: float = 1.8
@export var spark_flash_energy: float = 2.6
@export var spark_flash_period: float = 0.16

@export_category("Plasma Field")
@export var field_enabled: bool = true
@export var field_radius: float = 62.0
@export var field_color := Color(0.3, 1.05, 0.09, 1.0)
@export var swamp_color := Color(0.22, 0.58, 0.14, 1.0)
@export var field_light_energy: float = 1.4

@export_category("Hit Burst")
@export var burst_count: int = 24
@export var burst_speed: float = 180.0
@export var respawn_delay: float = 5.0

@onready var glow: PointLight2D = $Glow
@onready var lightning_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lightning_glow: AnimatedSprite2D = $LightningGlow
@onready var arc_lights: Array[PointLight2D] = [$ArcLightA, $ArcLightB, $ArcLightC]
@onready var sparks: GPUParticles2D = $Sparks
@onready var zap_sound: AudioStreamPlayer2D = $ZapSound
@onready var ambient_sound: AudioStreamPlayer2D = $AmbientSound

var lightning := []
var lightning_halos := []
var refresh_timer := 0.0
var damage_timer := 0.0
var active := true
var player_inside: Node2D
var field_dots: Array[Sprite2D] = []
var field_offsets: Array[Vector2] = []
var field_speeds: Array[float] = []
var field_phases: Array[float] = []
var field_time := 0.0
var respawning := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	ambient_sound.finished.connect(_on_ambient_finished)
	lightning_sprite.play("idle")
	lightning_glow.play("idle")
	_create_field_dots()
	_update_field_lights()
	for index in bolt_count:

		var bolt := Line2D.new()
		bolt.width = 2.0
		bolt.default_color = Color(1.8, 2.7, 3.2, 0.95)
		bolt.joint_mode = Line2D.LINE_JOINT_SHARP
		bolt.z_index = 4
		add_child(bolt)
		lightning.append(bolt)

		var halo := Line2D.new()
		halo.width = 11.0
		halo.default_color = Color(0.15, 0.65, 1.0, 0.2)
		halo.joint_mode = Line2D.LINE_JOINT_SHARP
		halo.z_index = 3
		add_child(halo)
		lightning_halos.append(halo)
	_refresh_lightning()
	ambient_sound.play()


func _process(delta: float) -> void:
	if not active:
		return
	refresh_timer -= delta
	damage_timer = maxf(0.0, damage_timer - delta)
	if is_instance_valid(player_inside) and damage_timer <= 0.0:
		_shock_player()
	if refresh_timer <= 0.0:
		refresh_timer = refresh_rate
		_refresh_lightning()
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.009) * 0.18
	var flash_phase := fmod(Time.get_ticks_msec() * 0.001, spark_flash_period) / spark_flash_period
	var flash_falloff := exp(-flash_phase * 7.0)
	glow.energy = glow_energy * pulse + spark_flash_energy * flash_falloff
	lightning_glow.modulate.a = 0.22 + pulse * 0.08
	lightning_glow.scale = Vector2.ONE * (0.43 + pulse * 0.015)
	field_time += delta
	_update_field_lights()
	_update_field_dots()


func _create_field_dots() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for index in range(110):
		var dot := Sprite2D.new()
		dot.texture = SOFT_DOT_TEXTURE
		dot.material = additive
		dot.z_index = 2
		add_child(dot)
		field_dots.append(dot)
		var angle := randf() * TAU
		var distance := sqrt(randf()) * field_radius
		field_offsets.append(Vector2.from_angle(angle) * distance)
		field_speeds.append(randf_range(-0.9, 1.1))
		field_phases.append(randf() * TAU)


func _update_field_dots() -> void:
	if not field_enabled:
		return
	var time := Time.get_ticks_msec() * 0.001
	for index in field_dots.size():
		var base := field_offsets[index]
		var angle := field_speeds[index] * field_time
		var rotated := base.rotated(angle)
		var drift := Vector2(
			sin(time * 1.7 + field_phases[index]) * 8.0,
			cos(time * 2.1 + field_phases[index] * 1.3) * 8.0
		)
		var dot: Sprite2D = field_dots[index]
		dot.position = (rotated + drift).limit_length(field_radius)
		var twinkle := 0.5 + 0.5 * sin(time * 7.0 + field_phases[index])
		dot.scale = Vector2.ONE * (0.045 + twinkle * 0.045)
		var dot_color := field_color if index % 3 != 0 else swamp_color
		dot.modulate = Color(dot_color.r, dot_color.g, dot_color.b, 0.16 + twinkle * 0.48)


func _update_field_lights() -> void:
	for index in arc_lights.size():
		var angle := field_time * (0.55 + index * 0.18) + index * TAU / float(arc_lights.size())
		var light: PointLight2D = arc_lights[index]
		var distance := field_radius * (0.45 + index * 0.18)
		light.position = Vector2.from_angle(angle) * distance
		light.energy = field_light_energy * (0.8 + sin(Time.get_ticks_msec() * 0.006 + index) * 0.2)


func _draw() -> void:
	pass


func _refresh_lightning() -> void:
	for index in lightning.size():
		var bolt: Line2D = lightning[index]
		var angle := (TAU / maxf(1.0, float(lightning.size()))) * index + randf_range(-0.3, 0.3)
		var end_point := Vector2.from_angle(angle) * randf_range(radius * 0.7, radius)
		var points := PackedVector2Array([Vector2.ZERO])
		var segments := randi_range(4, 6)
		for segment in range(1, segments):
			var progress := float(segment) / float(segments)
			var point := end_point * progress
			point += Vector2(-end_point.y, end_point.x).normalized() * randf_range(-12.0, 12.0)
			points.append(point)
		points.append(end_point)
		bolt.points = points
		bolt.modulate.a = randf_range(0.65, 1.0)
		var halo: Line2D = lightning_halos[index]
		halo.points = points
		halo.modulate.a = bolt.modulate.a * 0.65


func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if body.is_in_group("projectile") or body.name == "Bullet":
		body.queue_free()
		_shock()
		_deactivate_and_respawn()
		return
	if body.is_in_group("player") or body.name == "Player":
		player_inside = body
		_shock_player()


func _on_body_exited(body: Node2D) -> void:
	if body == player_inside:
		player_inside = null


func _on_area_entered(area: Area2D) -> void:
	if active and (area.is_in_group("projectile") or area.name == "Bullet"):
		area.queue_free()
		_shock()
		_deactivate_and_respawn()


func _shock_player() -> void:
	if not is_instance_valid(player_inside):
		return
	if damage_timer > 0.0:
		return
	damage_timer = damage_cooldown
	_shock()
	Signals.emit_signal("enemy_attack", damage)


func _shock() -> void:
	zap_sound.play()
	_refresh_lightning()
	sparks.restart()
	var tween := create_tween()
	tween.tween_property(glow, "energy", glow_energy * 3.0, 0.06)
	tween.tween_property(glow, "energy", glow_energy, 0.2)


func _spawn_hit_burst() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for index in burst_count:
		var drop := Sprite2D.new()
		drop.texture = SOFT_DOT_TEXTURE
		drop.material = additive
		drop.z_index = 20
		drop.global_position = global_position
		drop.scale = Vector2.ONE * randf_range(0.035, 0.085)
		drop.modulate = Color(swamp_color.r, swamp_color.g, swamp_color.b, randf_range(0.65, 1.0))
		scene.add_child(drop)
		var direction := Vector2.from_angle(randf() * TAU)
		var distance := randf_range(burst_speed * 0.45, burst_speed)
		var target := global_position + direction * distance
		var tween := scene.create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(drop, "global_position", target, randf_range(0.35, 0.7))
		tween.tween_property(drop, "modulate:a", 0.0, 0.7)
		tween.tween_property(drop, "scale", Vector2.ZERO, 0.7)
		tween.chain().tween_callback(drop.queue_free)


func _deactivate_and_respawn() -> void:
	if respawning:
		return
	respawning = true
	active = false
	# Collision signals lock Area2D monitoring until the physics callback ends.
	set_deferred("monitoring", false)
	_spawn_hit_burst()
	ambient_sound.stop()

	var disappear := create_tween()
	disappear.set_parallel(true)
	disappear.tween_property(self, "modulate:a", 0.0, 0.18)
	disappear.tween_property(glow, "energy", 0.0, 0.18)
	await disappear.finished
	visible = false
	await get_tree().create_timer(respawn_delay).timeout
	if not is_instance_valid(self):
		return

	field_time = 0.0
	_update_field_dots()
	_update_field_lights()
	modulate.a = 0.0
	glow.energy = 0.0
	visible = true
	ambient_sound.play()

	var appear := create_tween()
	appear.set_parallel(true)
	appear.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(self, "modulate:a", 1.0, 0.55)
	appear.tween_property(glow, "energy", glow_energy, 0.65)
	await appear.finished
	active = true
	set_deferred("monitoring", true)
	respawning = false


func _on_ambient_finished() -> void:
	if active:
		ambient_sound.play()
