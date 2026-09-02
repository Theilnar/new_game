extends Node2D

@export var fire_rate: float = 0.45
@export var bullet_speed: float = 5500.0
@export var damage: int = 10
@export var bullet_scene: PackedScene

@export_category("Ammo")
@export var magazine_size: int = 9
@export var reserve_ammo: int = 30
@export var reload_time: float = 0.8

# Отдача
@export_category("Recoil")
@export var recoil_angle: float = 5.0
@export var recoil_time: float = 0.05
@export var recoil_return_time: float = 0.10

# Muzzle Flash
@export_category("Muzzle Flash")
@export var muzzle_flash_scene: PackedScene  # Сцена вспышки
@export var muzzle_flash_duration: float = 0.05

# Звук
@export_category("Sound")
@export var shoot_sound: AudioStream
@export var shoot_volume_db: float = -10.0
@export var empty_click_sound: AudioStream
@export var empty_click_volume_db: float = -16.0
@export var reload_sound: AudioStream
@export var reload_volume_db: float = -12.0

@onready var shoot_point: Node2D = $ShootPoint
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var muzzle: Node2D = $Muzzle
@onready var weapon_sprite: AnimatedSprite2D = $AnimatedSprite2D

var can_shoot: bool = true
var is_recoiling: bool = false
var is_reloading: bool = false
var ammo_in_magazine: int
var ammo_label: Label


func _ready() -> void:
	ammo_in_magazine = magazine_size
	ammo_label = get_tree().current_scene.get_node_or_null("CanvasLayer/Ammo") as Label
	update_ammo_ui()

	if audio_player == null:
		audio_player = AudioStreamPlayer2D.new()
		add_child(audio_player)
	
	audio_player.volume_db = shoot_volume_db


func _process(_delta: float) -> void:
	pass

func set_aim_facing(facing_right: bool) -> void:
	# The player owns the complete aiming direction. This avoids using the
	# weapon's offset position, which is unstable when the mouse is nearby.
	weapon_sprite.flip_h = false
	weapon_sprite.flip_v = not facing_right


func start_shooting() -> void:
	shoot()


func stop_shooting() -> void:
	pass


func force_stop_shooting() -> void:
	pass


func shoot() -> void:
	if not can_shoot or is_reloading:
		return

	if bullet_scene == null:
		push_error("Weapon: Bullet Scene не назначена в Inspector!")
		return

	if ammo_in_magazine <= 0:
		play_empty_click_sound()
		return

	can_shoot = false
	ammo_in_magazine -= 1
	update_ammo_ui()

	fire()
	recoil()
	spawn_muzzle_flash()
	play_shoot_sound()

	await get_tree().create_timer(fire_rate * 0.1).timeout
	can_shoot = true


func reload() -> void:
	if is_reloading or ammo_in_magazine >= magazine_size or reserve_ammo <= 0:
		return

	is_reloading = true
	can_shoot = false
	play_reload_sound()
	weapon_sprite.play("reload")
	await get_tree().create_timer(reload_time).timeout

	var needed_ammo: int = magazine_size - ammo_in_magazine
	var loaded_ammo: int = mini(needed_ammo, reserve_ammo)
	ammo_in_magazine += loaded_ammo
	reserve_ammo -= loaded_ammo
	is_reloading = false
	can_shoot = true
	weapon_sprite.play("idle")
	update_ammo_ui()


func play_reload_sound() -> void:
	if reload_sound == null or audio_player == null:
		return

	audio_player.stream = reload_sound
	audio_player.pitch_scale = 0.7
	audio_player.volume_db = reload_volume_db
	audio_player.play()


func update_ammo_ui() -> void:
	if is_instance_valid(ammo_label):
		ammo_label.text = "%d/%d" % [ammo_in_magazine, reserve_ammo]


func play_empty_click_sound() -> void:
	if empty_click_sound == null or audio_player == null:
		return

	audio_player.stream = empty_click_sound
	audio_player.pitch_scale = 0.45
	audio_player.volume_db = empty_click_volume_db
	audio_player.play()


func fire():
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = shoot_point.global_position

	# Use the barrel axis so the projectile always follows the weapon visually.
	var direction := shoot_point.global_transform.x.normalized()

	bullet.setup(direction, bullet_speed, damage)


func recoil():
	if is_recoiling:
		return

	is_recoiling = true

	var start_rotation := rotation
	
	var random_sign = 1 if randf() > 0.5 else -1
	var recoil_rot := start_rotation + deg_to_rad(recoil_angle * random_sign)

	var tween := create_tween()

	tween.tween_property(
		self,
		"rotation",
		recoil_rot,
		recoil_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"rotation",
		start_rotation,
		recoil_return_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished

	is_recoiling = false


func spawn_muzzle_flash():
	if muzzle_flash_scene == null:
		# Если нет сцены - создаем простую вспышку из кода
		create_simple_muzzle_flash()
		return
	
	var flash = muzzle_flash_scene.instantiate()
	get_tree().current_scene.add_child(flash)
	
	flash.global_position = muzzle.global_position
	flash.global_rotation = muzzle.global_rotation
	
	# Уничтожаем через время
	await get_tree().create_timer(muzzle_flash_duration).timeout
	if is_instance_valid(flash):
		flash.queue_free()


func create_simple_muzzle_flash():
	var flash = Node2D.new()
	flash.global_position = muzzle.global_position
	flash.global_rotation = muzzle.global_rotation
	
	# Создаем простую вспышку из ColorRect
	var rect = ColorRect.new()
	rect.size = Vector2(30, 30)
	rect.color = Color(1, 0.8, 0.3, 0.9)  # Желто-оранжевый
	rect.position = Vector2(-15, -15)
	flash.add_child(rect)
	
	# Добавляем вторую вспышку поменьше и ярче
	var rect2 = ColorRect.new()
	rect2.size = Vector2(15, 15)
	rect2.color = Color(1, 1, 1, 0.8)  # Белый
	rect2.position = Vector2(-7.5, -7.5)
	flash.add_child(rect2)
	
	get_tree().current_scene.add_child(flash)
	
	# Анимация исчезновения
	var tween = flash.create_tween()
	tween.parallel().tween_property(rect, "color:a", 0.0, 0.05)
	tween.parallel().tween_property(rect2, "color:a", 0.0, 0.05)
	tween.parallel().tween_property(flash, "scale", Vector2(0.5, 0.5), 0.05)
	
	await tween.finished
	if is_instance_valid(flash):
		flash.queue_free()


func play_shoot_sound():
	if shoot_sound == null:
		return
	
	if audio_player == null:
		return
	
	audio_player.stream = shoot_sound
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.volume_db = shoot_volume_db
	audio_player.play()
