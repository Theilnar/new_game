extends CharacterBody2D

var direction := Vector2.RIGHT
var speed := 700.0
var damage := 10

const BULLET_COLLISION_MASK := (1 << 0) | (1 << 3)

@export var lifetime: float = 5.0  # Время жизни пули
@export var impact_scene: PackedScene  # Сцена эффекта попадания (опционально)

# Звуки попадания (массив для случайного выбора)
@export_category("Hit Sounds")
@export var hit_sounds: Array[AudioStream] = []  # Массив звуков попадания
@export var hit_volume_db: float = -15.0  # Громкость звука попадания (тише)


func setup(start_direction: Vector2, bullet_speed: float, bullet_damage: int):
	direction = start_direction.normalized()
	speed = bullet_speed
	damage = bullet_damage
	collision_layer = 0
	collision_mask = BULLET_COLLISION_MASK

	rotation = direction.angle()
	
	# Авто-удаление через время
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	var motion: Vector2 = direction * speed * delta
	var collision: KinematicCollision2D = move_and_collide(motion)

	if collision:
		on_hit(collision)


func on_hit(collision: KinematicCollision2D):
	var collider = collision.get_collider()
	var hit_position := collision.get_position()
	var hit_normal := collision.get_normal()
	
	# Создаем эффект попадания в месте столкновения
	create_impact_effect(hit_position, hit_normal)
	
	# Воспроизводим звук попадания (тише и со случайным выбором)
	play_hit_sound(hit_position)
	
	# Если попали в StaticBody2D или TileMap
	if collider is StaticBody2D or collider is TileMap or collider is TileMapLayer:
		queue_free()
		return
	
	# Если попали в CharacterBody2D (враг)
	if collider.has_method("take_damage"):
		collider.take_damage(damage, direction)
		queue_free()
		return
	
	# Если попали в другой объект
	if collider is Node2D:
		queue_free()
		return


func create_impact_effect(position: Vector2, normal: Vector2 = Vector2.ZERO):
	# Вариант 1: Используем готовую сцену эффекта
	if impact_scene:
		var impact = impact_scene.instantiate()
		get_tree().current_scene.add_child(impact)
		impact.global_position = position
		
		# Поворачиваем эффект в сторону нормали (опционально)
		if normal != Vector2.ZERO:
			impact.rotation = normal.angle()
		
		# Удаляем через время
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(impact):
			impact.queue_free()
		return
	
	# Вариант 2: Создаем простой эффект из кода
	var impact_particles = create_particle_effect(position)
	get_tree().current_scene.add_child(impact_particles)
	
	# Удаляем через время
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(impact_particles):
		impact_particles.queue_free()


func create_particle_effect(position: Vector2) -> Node2D:
	var container = Node2D.new()
	container.global_position = position
	
	# Создаем несколько частиц для эффекта
	for i in range(8):
		var particle = ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.color = Color(1, 0.8, 0.4, 0.9)  # Желтоватый цвет
		particle.position = Vector2.ZERO
		container.add_child(particle)
		
		# Разлетаемся в разные стороны
		var angle = randf() * TAU
		var distance = randf_range(5, 20)
		var target_pos = Vector2(cos(angle), sin(angle)) * distance
		
		var tween = container.create_tween()
		tween.parallel().tween_property(particle, "position", target_pos, 0.2).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(particle, "color:a", 0.0, 0.2).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(particle, "size", Vector2(1, 1), 0.2)
	
	return container


func play_hit_sound(position: Vector2):
	# Проверяем, есть ли звуки в массиве
	if hit_sounds.is_empty():
		return
	
	# Выбираем случайный звук из массива
	var random_index = randi() % hit_sounds.size()
	var selected_sound = hit_sounds[random_index]
	
	if selected_sound == null:
		return
	
	# Создаем временный AudioStreamPlayer2D для звука попадания
	var audio_player = AudioStreamPlayer2D.new()
	get_tree().current_scene.add_child(audio_player)
	
	audio_player.stream = selected_sound
	audio_player.global_position = position
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.volume_db = hit_volume_db
	audio_player.play()
	
	# Просто ждем 0.5 секунды и удаляем (проще и надежнее)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(audio_player):
		audio_player.queue_free()
