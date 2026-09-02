extends CharacterBody2D
#extends Node2D
signal health_changed(new_health)



#const GRAVITY = 200
@onready var MOVE_SPEED: int = 120 # Скорость перемещения персонажа в пикселях
const JUMP_POWER: int = 350 # Скорость прыжка
#@onready var state_machine = $AnimationTree.get('parameters/playback')
var RUN_SPEED: int = 1

@export var walk_sound_1: AudioStream
@export var walk_sound_2: AudioStream
@export var walk_sound_3: AudioStream
@export var jump_sound: AudioStream
@export var climb_sound: AudioStream
@export var fall_sound: AudioStream
@export var water_move_sound: AudioStream
@export var dive_sound: AudioStream
@export var surfacing_sound: AudioStream

const WALK_STEP_INTERVAL := 0.38
const RUN_STEP_INTERVAL := 0.24
const CLIMB_STEP_INTERVAL := 0.28
const WATER_STEP_INTERVAL := 0.36

var _walk_streams: Array[AudioStream] = []
var _jump_stream: AudioStream
var _climb_stream: AudioStream
var _fall_stream: AudioStream
var _water_stream: AudioStream
var _dive_stream: AudioStream
var _surfacing_stream: AudioStream
var _rng := RandomNumberGenerator.new()
var _walk_sfx_timer: float = 0.0
var _climb_sfx_timer: float = 0.0
var _water_sfx_timer: float = 0.0

var _footstep_player: AudioStreamPlayer2D
var _jump_player: AudioStreamPlayer2D
var _climb_player: AudioStreamPlayer2D

var damage_basic = 10
var damage_multiplier = 1
var damage_current 

var attack_cooldown = false

var raycast_wall_position

var hero_ladder = false #Если мы на лестнице 

var ledge_right_posx
var ledge_right_posy
var ledge_left_posx
var ledge_left_posy

var water_area1
var water_area2
var water_area3

var ladder_position_x #позиция лестницы

var water_collision #вода

# --- Переменные для механики ныряния в воде ---
var is_diving: bool = false
var dive_timer: float = 0.0
const MAX_DIVE_TIME: float = 5.0

@export var WATER_SPEED_MULTIPLIER: float = 0.3 # Множитель скорости в воде

var dive_cooldown: float = 0.0 # Таймер перезарядки перед следующим нырянием
const DIVE_COOLDOWN_TIME: float = 2.0 # Задержка после полного (авто) ныряния

var is_forced_surfacing: bool = false # Флаг, что произошло авто-выплывание из-за лимита времени

# RayCast2D для обнаружения уступов и стен
@onready var raycast_up = $RayCast_up_for_ledge  # для проверки выступов
@onready var raycast_down = $RayCast_down_for_ledge # для проверки выступов
@onready var raycast_hands_coll = $RayCast_hands # для проверки для рук

@onready var raycast_hero_push_coll = $RayCast_hero_push # для проверки стороны при толкании предмета

var hero_back_coll_left = false  #коллизия для спины игрока, при перетаскивании спиной
var hero_back_coll_right = false 

var hero_coll_for_climb_left = false
var hero_coll_for_climb_right = false

#все для спуска
var descent_ledge_right = true  # проверка для спуска около выступа
var descent_ledge_left = true  # проверка для спуска около выступа
var rotate_player

var descent_ledge_center

var is_on_ledge_up = false
var is_on_ledge_down = false
var raycast_hands = false
var raycast_hero_push = false

var dir_look #куда смотрим
var on_ledge: bool = false
var collision_sitdown = false
var climbing: bool = false # Нужно чтобы определять, карабкается ли игрок по стене, или нет.
var max_health = 100
var combo = false

var turn_around_left = false
var turn_around_right = true
var aim_facing_right := false
const AIM_SIDE_DEADZONE := 4.0

@onready var anim = $AnimatedSprite2D
@onready var aim_anim: AnimatedSprite2D = $AimSprite2D
@onready var aim_rig: Node2D = $AimRig
@onready var aim_body_sprite: Sprite2D = $AimRig/BodySprite
@onready var aim_head_pivot: Node2D = $AimRig/HeadPivot
@onready var aim_arms_pivot: Node2D = $AimRig/ArmsPivot
@onready var aim_arms_pivot_default_position: Vector2 = aim_arms_pivot.position
@onready var aim_head_sprite: Sprite2D = $AimRig/HeadPivot/HeadSprite
@onready var aim_arms_sprite: Sprite2D = $AimRig/ArmsPivot/ArmsSprite
@onready var aim_head_default_position: Vector2 = aim_head_sprite.position
@onready var aim_arms_default_position: Vector2 = aim_arms_sprite.position
@onready var animPlayer = $AnimationPlayer

@onready var weapon_pivot: Node2D = $AimRig/ArmsPivot/WeaponPivot
@onready var weapon = $AimRig/ArmsPivot/WeaponPivot/Weapon
@onready var weapon_pivot_default_position: Vector2 = weapon_pivot.position


#позиция игрока для старта
@onready var startPosition = $"../../Start_position"

@export var aim_arms_right_offset_x: float = -8.0

var ledge_testing = false
var health = 100
var gold = 0
var is_dead := false
var death_restart_requested := false
var state_machine_info # для вывода состояния

var box_push_x = 1
var push_mode = false # находимся ли мы в режиме переноса (toggle по кнопке F)

# Сила для оторвание деревянной перегородки
var break_force = 50
# Время, в течение которого игрок должен быстро нажимать кнопку для оторвание деревянной перегородки
var break_time = 2.0
# Время, прошедшее с момента начала оторвание деревянной перегородки
var break_timer = 0.0
# Флаг, указывающий, находится ли игрок рядом с деревянной перегородкой
var is_near_barrier = false
# Узел Area2D для обнаружения деревянной перегородки
@onready var barrier_area = $"../../wooden_wall/BarrierArea"

var player_pos  #для глобальной позиции игрока

var strong_fall_state = false
var strong_fall_sfx_played = false

var climb_on = false
var climbing_lock = false # блокирует ввод (особенно влево-вправо), пока не завершится подъём с выступа
var drop_from_ledge_after_damage = false

var ladder_pos_x

enum { 
	IN_AIR, # В воздухе
	ON_FLOOR, # На полу, ходьба
	SITDOWN, #приседаем
	BLOCK, # блок или толкаем
	ATTACK, #атака
	ATTACK2,
	ATTACK3,
	ON_CLIMBING, #на уступе
	CLIMBING_DOWN, # спуск на уступ
	SLIDE, #скольжение
	ON_WALL, # На стене
	STRONG_FALL, #падение с высоты
	DAMAGE, #урон
	ON_WALL_JUMP,
	TURN_AROUND_LEFT, #поворот влево
	TURN_AROUND_RIGHT, #поворот вправо
	ON_PUSH, #толкаем вещи
	ON_LADDER, # на лестницу
	IN_WATER
}
var state = IN_AIR

func _ready() -> void:
	position.x = startPosition.position.x
	position.y = startPosition.position.y
	
	health = max_health
	_rng.randomize()
	_setup_audio()
	Signals.connect('enemy_attack', Callable(self, '_on_damage_received'))

func signal_function():
	print('siganl prishel')
	
func update_state() -> void:
	$VBoxContainer/FSM.text = str(state_machine_info)
	
	is_on_ledge_up = raycast_up.get_collider() != null
	is_on_ledge_down = raycast_down.get_collider() != null
	raycast_hands = raycast_hands_coll.get_collider() != null
	raycast_hero_push = raycast_hero_push_coll.get_collider() != null

	# --- ПЕРЕКЛЮЧЕНИЕ РЕЖИМА ПЕРЕНОСА ---
	if Input.is_action_just_pressed("block") and state != STRONG_FALL and state != DAMAGE and state != ON_LADDER:
		if push_mode == false:
			if Global.box_player_collision == true and raycast_hero_push == true and is_on_floor():
				push_mode = true
		else:
			push_mode = false
			box_push_x = 0
			Global.push_onoff = false
			Signals.emit_signal("box_push", box_push_x)
			state = ON_FLOOR

	if push_mode == true and (Global.box_player_collision == false or raycast_hero_push == false or not is_on_floor()):
		push_mode = false
		box_push_x = 0
		Global.push_onoff = false
		Signals.emit_signal("box_push", box_push_x)
	
	damage_current = damage_basic * damage_multiplier

	# Зацеп за стену
	if (state == IN_AIR or state == IN_WATER) and is_on_ledge_up == false and is_on_ledge_down == true:
		velocity.y = 0
		state = ON_WALL
		ledge_right_posx = $right_ledge_grab.global_position.x
		ledge_right_posy = $right_ledge_grab.global_position.y
		ledge_left_posx = $left_ledge_grab.global_position.x
		ledge_left_posy = $left_ledge_grab.global_position.y

	elif is_on_floor() and state != IN_WATER and state != ON_LADDER and state != TURN_AROUND_LEFT and state != TURN_AROUND_RIGHT and state != CLIMBING_DOWN and state != DAMAGE and state != ATTACK2 and state != ATTACK3 and state != ATTACK and state != ON_CLIMBING and state != SITDOWN and state != STRONG_FALL:
		state = ON_FLOOR
		
	elif water_collision == true:
		if state != ON_LADDER and state != ON_WALL and state != CLIMBING_DOWN and state != ON_CLIMBING:
			state = IN_WATER

	elif !is_on_floor() and state!= IN_WATER and state != ON_LADDER and state != TURN_AROUND_LEFT and state != TURN_AROUND_RIGHT and state != CLIMBING_DOWN and state != ON_WALL_JUMP and state != ON_CLIMBING and state != ON_WALL and state != STRONG_FALL:
		if (velocity.y > 650):
			strong_fall_state = true
			if not strong_fall_sfx_played:
				_play_fall_sfx()
				strong_fall_sfx_played = true
			print('strong fall')
			state = STRONG_FALL
		else:
			state = IN_AIR
			
		if velocity.y > 50:
			animPlayer.play("fall")

	if Input.is_action_just_pressed("up") and state != ON_LADDER and state != ON_CLIMBING and ledge_testing == true and state == ON_WALL and climb_on == true and state != IN_AIR and state != STRONG_FALL:
		velocity.y = 0
		print('что за нах')
		state = ON_CLIMBING

	elif Input.is_action_pressed("up") and (state == ON_FLOOR or state == IN_AIR or state == ON_WALL_JUMP):
		if Global.is_climbing == true:
			var tween = get_tree().create_tween()
			tween.parallel().tween_property(self, "position:x", ladder_position_x, 0.4)
			state = ON_LADDER

	if Input.is_action_pressed("down") and state != IN_WATER and ledge_testing == true and state == ON_WALL:
		state_machine_info = "OFF climbing"
		if water_collision == true:
			var tween = get_tree().create_tween()
			tween.tween_property(self, "position", Vector2(global_position.x, water_area3), 0.2)
			await tween.finished
		velocity.y += 80
		is_on_ledge_down = false
		state = IN_AIR

	if is_near_barrier and Input.is_action_just_pressed("attack") and state == ON_FLOOR and state != STRONG_FALL:
		break_timer += 0.5
		print(break_time, ' - ', break_timer)
	elif break_timer >= 0:
		break_timer -= 0.005
		print(break_time, ' - ', break_timer)

	if break_timer >= break_time:
		break_barrier()		

	if raycast_hands == true and state == IN_AIR:
		animPlayer.play("jump_hands")

	if Input.is_action_pressed("down") and state != IN_WATER and state != ON_LADDER and is_on_floor() and state != IN_AIR and state!= ON_WALL and state != ON_CLIMBING and state != STRONG_FALL and state != ON_PUSH:
		if (descent_ledge_left == false and descent_ledge_right == true) or (descent_ledge_left == true and descent_ledge_right == false):
			state = CLIMBING_DOWN
		elif is_on_floor() and state == ON_FLOOR:	
			state = SITDOWN

	elif Global.box_player_collision == true and raycast_hero_push and push_mode == true and is_on_floor() and state != STRONG_FALL:
		state = ON_PUSH
		print(Global.player_pushbox_left, '  ', Global.player_pushbox_right)

		if Input.is_action_pressed("right") and hero_back_coll_right == false and raycast_hero_push == true:
			if Global.player_pushbox_right == false:
				box_push_x = 0.5
				position.x += box_push_x
				Global.push_onoff = true
		elif Input.is_action_pressed("left") and hero_back_coll_left == false and raycast_hero_push == true:
			if Global.player_pushbox_left == true:
				box_push_x = -0.5
				position.x -= 0.5
				Global.push_onoff = true	
		else:
			box_push_x = 0
			Global.push_onoff = false
		Signals.emit_signal("box_push", box_push_x)

	elif Input.is_action_just_pressed("attack") and state != ON_LADDER and attack_cooldown == false and state != ATTACK3 and state != ATTACK2 and state != IN_AIR and state != ON_WALL and state != ON_CLIMBING and state != SITDOWN and state != STRONG_FALL and state != ON_PUSH:

		state = ATTACK

		# Сразу останавливаем автоматическую стрельбу
		weapon.force_stop_shooting()

	elif state != IN_WATER and state != ATTACK2 and state != ON_LADDER and state != TURN_AROUND_LEFT and state != TURN_AROUND_RIGHT and state != CLIMBING_DOWN and state != ON_WALL_JUMP and state != ATTACK3 and state != ATTACK and state != DAMAGE and state != IN_AIR and state!= ON_WALL and state != ON_CLIMBING and collision_sitdown == false and state != STRONG_FALL and state != ON_PUSH:
		state = ON_FLOOR
		Global.push_onoff = false

	if Global.player_on_visibility_area == true and (state == SITDOWN or state == TURN_AROUND_LEFT or state == TURN_AROUND_RIGHT):
		Global.player_visibility = true
	else:
		Global.player_visibility = false

func _setup_audio() -> void:
	_footstep_player = AudioStreamPlayer2D.new()
	_footstep_player.name = "FootstepSfx"
	add_child(_footstep_player)

	_jump_player = AudioStreamPlayer2D.new()
	_jump_player.name = "JumpSfx"
	add_child(_jump_player)

	_climb_player = AudioStreamPlayer2D.new()
	_climb_player.name = "ClimbSfx"
	add_child(_climb_player)

	_walk_streams.clear()

	if walk_sound_1 != null:
		_walk_streams.append(walk_sound_1)
	if walk_sound_2 != null:
		_walk_streams.append(walk_sound_2)
	if walk_sound_3 != null:
		_walk_streams.append(walk_sound_3)

	_jump_stream = jump_sound
	_climb_stream = climb_sound
	_fall_stream = fall_sound
	_water_stream = water_move_sound
	_dive_stream = dive_sound
	_surfacing_stream = surfacing_sound

func _update_sfx_timers(delta: float) -> void:
	_walk_sfx_timer = maxf(0.0, _walk_sfx_timer - delta)
	_climb_sfx_timer = maxf(0.0, _climb_sfx_timer - delta)
	_water_sfx_timer = maxf(0.0, _water_sfx_timer - delta)

func _play_walk_step(is_running: bool) -> void:
	if _walk_streams.is_empty() or _walk_sfx_timer > 0.0:
		return

	_walk_sfx_timer = RUN_STEP_INTERVAL if is_running else WALK_STEP_INTERVAL
	_footstep_player.stream = _walk_streams[_rng.randi_range(0, _walk_streams.size() - 1)]
	_footstep_player.pitch_scale = _rng.randf_range(0.96, 1.04) * (1.08 if is_running else 1.0)
	_footstep_player.volume_db = -7.0 if is_running else -9.0
	_footstep_player.play()

func _play_jump_sfx() -> void:
	if _jump_stream == null:
		return
	_jump_player.stream = _jump_stream
	_jump_player.pitch_scale = _rng.randf_range(0.98, 1.03)
	_jump_player.volume_db = -6.0
	_jump_player.play()

func _play_climb_sfx() -> void:
	if _climb_stream == null or _climb_sfx_timer > 0.0:
		return
	_climb_sfx_timer = CLIMB_STEP_INTERVAL
	_climb_player.stream = _climb_stream
	_climb_player.pitch_scale = _rng.randf_range(0.97, 1.03)
	_climb_player.volume_db = -8.0
	_climb_player.play()

func _play_water_move_sfx() -> void:
	if _water_stream == null or _water_sfx_timer > 0.0:
		return
	_water_sfx_timer = WATER_STEP_INTERVAL
	_footstep_player.stream = _water_stream
	_footstep_player.pitch_scale = _rng.randf_range(0.95, 1.02)
	_footstep_player.volume_db = -11.0
	_footstep_player.play()

func _play_fall_sfx() -> void:
	if _fall_stream == null:
		return
	_jump_player.stream = _fall_stream
	_jump_player.pitch_scale = _rng.randf_range(0.97, 1.02)
	_jump_player.volume_db = -5.0
	_jump_player.play()

func _play_dive_sfx() -> void:
	if _dive_stream == null:
		return
	_climb_player.stream = _dive_stream
	_climb_player.pitch_scale = _rng.randf_range(0.98, 1.03)
	_climb_player.volume_db = -7.0
	_climb_player.play()

func _play_surfacing_sfx() -> void:
	if _surfacing_stream == null:
		return
	_climb_player.stream = _surfacing_stream
	_climb_player.pitch_scale = _rng.randf_range(0.98, 1.03)
	_climb_player.volume_db = -7.0
	_climb_player.play()
		
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_weapon_aim()
	_update_sfx_timers(delta)
	# --- ОБРАБОТКА ТАЙМЕРОВ НЫРЯНИЯ ---
	if is_diving:
		dive_timer += delta
		# Заставляем всплывать, если достигнут лимит 5 сек
		if dive_timer >= MAX_DIVE_TIME:
			is_diving = false
			_play_surfacing_sfx()
			is_forced_surfacing = true # Включаем длинный отдых
			dive_cooldown = DIVE_COOLDOWN_TIME
			dive_timer = 0.0
	else:
		dive_timer = 0.0
		# Отсчитываем кулдаун только при вынужденном авто-всплытии
		if dive_cooldown > 0:
			dive_cooldown -= delta
			if dive_cooldown <= 0:
				is_forced_surfacing = false

	update_state()
	# Обновляем видимость оружия ПОСЛЕ обновления состояния
	update_weapon_visibility()
	update_aim_rig()
	match state:
		IN_AIR:
			state_machine_info = "IN AIR"
			move_character()
		ON_FLOOR:
			move_character()
			jump()
			if RUN_SPEED == 2:
				state_machine_info = "RUN"
			elif velocity.x != 0:
				state_machine_info = "WALK"
			else:
				state_machine_info = "IDLE"
		BLOCK:
			block_state()
			state_machine_info = "BLOCK"
		SITDOWN:
			sitdown_state()	
			move_character()
			if velocity.x != 0:
				state_machine_info = "SITDOWN WALK"
			else:
				state_machine_info = "SITDOWN"
		SLIDE:
			state_machine_info = "Slide"
			slide_state()
		ATTACK:
			state_machine_info = "ATTACK"
			attack_state()
		ATTACK2:
			attack2_state()	
			state_machine_info = "ATTACK2"
		ATTACK3:
			attack3_state()		
			state_machine_info = "ATTACK3"	
		ON_WALL:
			state_machine_info = "WALL"
			climb()
			jump()
		ON_CLIMBING:
			climbing_up()
			state_machine_info = "CLIMBING"
		STRONG_FALL:
			strong_fall()
		DAMAGE:
			on_damage()
		ON_WALL_JUMP:
			on_walljump()
			state_machine_info = "ON WALL JUMP"
		CLIMBING_DOWN:
			climbing_down_state()
			state_machine_info = "CLIMBING DOWN"
		TURN_AROUND_LEFT:
			state_machine_info = "TURN_AROUND_LEFT"
			turn_around_left_state()
		TURN_AROUND_RIGHT:
			state_machine_info = "TURN_AROUND_RIGHT"
			turn_around_right_state()
		ON_PUSH:
			state_machine_info = "PUSH"	
			move_character()
		ON_LADDER:
			state_machine_info = "ON LADDER"	
			state_ladder()
		IN_WATER:
			state_machine_info = "IN WATER"	
			state_water()

	$VBoxContainer/info.text = str(velocity.x)
	if not is_on_floor() and state != IN_WATER and state != ON_LADDER and state != ON_WALL and state != ON_CLIMBING and state != CLIMBING_DOWN:
		velocity += get_gravity() * delta

	if health <= 0:
		_enter_death_state()
		return

	move_and_slide()
	if velocity.x != 0 or velocity.y != 0:
		player_pos = self.position
		Signals.emit_signal('player_position_update', player_pos)

# ПЛАВАЕМ И НЫРЯЕМ
func state_water():
	velocity.y = 0	
	
	# 1. Ручной отпуск кнопки "down" — сбрасываем ныряние сразу БЕЗ кулдауна!
	if Input.is_action_just_released("down") and is_diving:
		is_diving = false
		_play_surfacing_sfx()
		is_forced_surfacing = false
		dive_cooldown = 0.0

	# 2. Попытка нырнуть
	# Ныряем, только если зажата "down" И нет активного кулдауна от авто-всплытия
	if Input.is_action_pressed("down") and dive_cooldown <= 0:
		if not is_diving:
			is_diving = true
			_play_dive_sfx()
			# Если есть отдельная анимация начала ныряния, воспроизводим её:
			if animPlayer.has_animation("divin_start"):
				animPlayer.play("divin_start")
				

		velocity.x = 0
		if position.y < water_area3 + 20:
			position.y = move_toward(position.y, water_area3 + 20, 2)
		
		if !animPlayer.is_playing() or animPlayer.current_animation != "divin_start":
			animPlayer.play("sitdown")
	else:
		# Если не зажата кнопка ныряния — гарантируем, что не в режиме diving
		if is_diving and dive_cooldown <= 0:
			is_diving = false

		# 3. Перемещение влево / вправо в воде
		if Input.is_action_pressed("left"):
			anim.flip_h = true
			$AttackDirection.rotation_degrees = 180
			raycast_up.target_position.x = -20
			raycast_down.target_position.x = -20
			raycast_hands_coll.target_position.x = -70
			raycast_hero_push_coll.target_position.x = -20
			velocity.x = -MOVE_SPEED * WATER_SPEED_MULTIPLIER
			animPlayer.play("sitdown_walk")
			_play_water_move_sfx()
			
		elif Input.is_action_pressed("right"):
			raycast_up.target_position.x = 20
			raycast_down.target_position.x = 20
			raycast_hands_coll.target_position.x = 70
			$AttackDirection.rotation_degrees = 0
			raycast_hero_push_coll.target_position.x = 20
			anim.flip_h = false
			velocity.x = MOVE_SPEED * WATER_SPEED_MULTIPLIER
			animPlayer.play("sitdown_walk")
			_play_water_move_sfx()
			
		elif Input.is_action_pressed("up"):
			if Global.is_climbing == true:
				var tween = get_tree().create_tween()
				tween.parallel().tween_property(self, "position:x", ladder_position_x, 0.4)
				await tween.finished
				state = ON_LADDER
			if ledge_testing == true and climb_on == true and state == ON_WALL:
				state = ON_CLIMBING

		# 4. Прыжок из воды
		elif Input.is_action_just_pressed("jump"):
			is_diving = false
			is_forced_surfacing = false
			dive_cooldown = 0.0
			_play_surfacing_sfx()

			var tween = get_tree().create_tween()
			tween.parallel().tween_property(self, "position:y", global_position.y - 25, 0.15)
			await tween.finished
			
			if state != ON_WALL:
				var tween1 = get_tree().create_tween()
				tween1.tween_property(self, "position", Vector2(position.x, water_area3), 0.15)

		elif state != ON_WALL:
			velocity.x = 0
			# Воспроизведение анимации всплытия / покоя
			if is_forced_surfacing:
				# Авто-всплытие: долгая анимация усталости или восстановления
				if animPlayer.has_animation("surfacing_heavy"):
					animPlayer.play("surfacing_heavy")
				else:
					animPlayer.play("sitdown")
			else:
				# Быстрое / обычное выныривание
				if animPlayer.has_animation("surfacing_fast"):
					animPlayer.play("surfacing_fast")
				else:
					animPlayer.play("sitdown")

	# 5. Возврат на поверхность воде
	if not is_diving and position.y > water_area3 and state != ON_WALL:
		position.y = move_toward(position.y, water_area3, 3)

# ЛЕСТНИЦА И ОСТАЛЬНЫЕ МЕТОДЫ ОСТАЮТСЯ БЕЗ ИЗМЕНЕНИЙ...
func state_ladder():
	if Input.is_action_pressed("up"):
		if Global.is_climbing == true:
			velocity.y = -30
			velocity.x = 0
			animPlayer.play("ladder_climbing")
			_play_climb_sfx()
		elif Global.is_climbing == false:
			var tween = get_tree().create_tween()
			tween.tween_property(self, "position", Vector2(global_position.x + 20, global_position.y - 5), 0.9)
			animPlayer.play("new_climbung_ledge_up")
			await animPlayer.animation_finished
			await tween.finished
			state = ON_FLOOR

	elif Input.is_action_pressed("down") and Global.is_climbing == true:
		if is_on_floor():
			state = ON_FLOOR
			hero_ladder = false
		else:
			velocity.y = +30
			velocity.x = 0
			animPlayer.play("ladder_climbing")
			_play_climb_sfx()

	elif Input.is_action_pressed("right") and velocity.y == 0:
		animPlayer.play("climbing")
		anim.flip_h = false
		if Input.is_action_just_pressed("jump"):
			hero_ladder = false
			velocity.y = -lerp(velocity.y, 650.0, 0.6)
			velocity.x = lerp(velocity.x, 350.0, 0.6)
			anim.flip_h = false
			raycast_up.target_position.x = 20
			raycast_hero_push_coll.target_position.x = 20
			raycast_down.target_position.x = 20
			raycast_hands_coll.target_position.x = 70
			$AttackDirection.rotation_degrees = 0
			state = IN_AIR
			animPlayer.play("jump_hands")
			await animPlayer.animation_finished

	elif Input.is_action_pressed("left") and velocity.y == 0:
		animPlayer.play("climbing")
		anim.flip_h = true
		if Input.is_action_just_pressed("jump"):
			hero_ladder = false
			velocity.y = -lerp(velocity.y, 650.0, 0.6)		
			velocity.x = lerp(velocity.x, -350.0, 0.6)
			anim.flip_h = true
			$AttackDirection.rotation_degrees = 180
			raycast_hero_push_coll.target_position.x = -20
			raycast_up.target_position.x = -20
			raycast_down.target_position.x = -20
			raycast_hands_coll.target_position.x = -70
			state = IN_AIR
			animPlayer.play("jump_hands")
			await animPlayer.animation_finished

	elif Input.is_action_just_pressed("block"):
		hero_ladder = false
		state = IN_AIR
	else:
		velocity.y = 0
		velocity.x = 0
		animPlayer.play("ladder_climbing_ilde")

func strong_fall():
	if velocity.y == 0 and strong_fall_state:
		velocity.x = move_toward(velocity.x, 0, float(MOVE_SPEED) / 10)
		state_machine_info = "STRONG FALL"
		animPlayer.play("strong_fall")
		await animPlayer.animation_finished
		strong_fall_state = false
		strong_fall_sfx_played = false
		state = ON_FLOOR
	elif strong_fall_state == false:
		strong_fall_sfx_played = false
		state = IN_AIR

func climbing_down_state():
	climb_on = false
	if descent_ledge_left == false and descent_ledge_right == true:	
		velocity.x = 0
		anim.flip_h = true
		animPlayer.play("ledge_grab_down_left")	
		raycast_up.target_position.x = 20
		raycast_hero_push_coll.target_position.x = 20
		raycast_down.target_position.x = 20
		raycast_hands_coll.target_position.x = 70
		var tween = get_tree().create_tween()
		if descent_ledge_center == true:
			var tweenB = get_tree().create_tween()
			tweenB.parallel().tween_property(self, "position", Vector2(global_position.x - 105, global_position.y), 0.6)
		tween.parallel().tween_property(self, "position", Vector2(global_position.x, global_position.y + 73), 0.9)
		await animPlayer.animation_finished
		await tween.finished
		ledge_right_posx = $right_ledge_grab.global_position.x
		ledge_right_posy = $right_ledge_grab.global_position.y
		ledge_left_posx = $left_ledge_grab.global_position.x
		ledge_left_posy = $left_ledge_grab.global_position.y
		state = ON_WALL

	elif descent_ledge_right == false and descent_ledge_left == true:
		velocity.x = 0
		anim.flip_h = false
		animPlayer.play("ledge_grab_down_left")	
		raycast_up.target_position.x = -20
		raycast_down.target_position.x = -20
		raycast_hands_coll.target_position.x = -70
		raycast_hero_push_coll.target_position.x = -20
		var tween = get_tree().create_tween()
		if descent_ledge_center == true:
			var tweenB = get_tree().create_tween()
			tweenB.parallel().tween_property(self, "position", Vector2(global_position.x + 105, global_position.y), 0.6)
		tween.parallel().tween_property(self, "position", Vector2(global_position.x, global_position.y + 73), 0.9)
		await animPlayer.animation_finished
		await tween.finished
		ledge_right_posx = $right_ledge_grab.global_position.x
		ledge_right_posy = $right_ledge_grab.global_position.y
		ledge_left_posx = $left_ledge_grab.global_position.x
		ledge_left_posy = $left_ledge_grab.global_position.y
		state = ON_WALL

func turn_around_left_state():
	animPlayer.play("turn_around_left")
	await animPlayer.animation_finished
	turn_around_left = false
	turn_around_right = true
	state = ON_FLOOR

func turn_around_right_state():
	animPlayer.play("turn_around_left")
	await animPlayer.animation_finished
	turn_around_left = true
	turn_around_right = false
	state = ON_FLOOR

func move_character() -> void:
	if climbing_lock: # пока не завершился подъём с выступа, движение и повороты не обрабатываем
		velocity.x = 0
		return

	if state == ON_FLOOR:
		MOVE_SPEED = 120
		$Head.disabled = false
		
	var direction = Input.get_axis('left', 'right')

	if direction:
		velocity.x = lerp(velocity.x, direction * MOVE_SPEED * RUN_SPEED, 0.06)
		if velocity.y == 0:
			if state == SITDOWN:
				if is_on_wall() and raycast_hands_coll:
					animPlayer.play("sitdown")
				else:
					animPlayer.play("sitdown_walk")
			elif is_on_wall() and raycast_hands_coll and state != ON_PUSH:
				animPlayer.play("wall_hands_forward")
			else:
				if state == ON_PUSH:
					if Input.is_action_pressed("right") and hero_back_coll_right == false and raycast_hero_push == true:
						if Global.player_pushbox_right == false:
							if dir_look == true:
								animPlayer.play("hero_push_walk")
							else:
								animPlayer.play("hero_push_back")
						elif Global.player_pushbox_right == true:
							animPlayer.play("hero_push_idle")
					elif Input.is_action_pressed("left") and hero_back_coll_left == false and raycast_hero_push == true:
						if Global.player_pushbox_left == false:
							if dir_look == true:
								animPlayer.play("hero_push_back")
							else:
								animPlayer.play("hero_push_walk")
						elif raycast_hero_push == true: 
							animPlayer.play("hero_push_back")
					elif raycast_hero_push == true:
						animPlayer.play("hero_push_idle")
				elif RUN_SPEED == 1:
					animPlayer.play("walking")
				else:
					animPlayer.play("run")
				if state == ON_FLOOR:
					_play_walk_step(Input.is_action_pressed("run"))
	else:
		velocity.x = move_toward(velocity.x, 0, float(MOVE_SPEED) / 5)

		if velocity.y == 0 and state == ON_FLOOR:
			animPlayer.play("idle")
		elif state == SITDOWN:	
			animPlayer.play("sitdown")
		elif state == ON_PUSH and (Global.player_pushbox_left == true or Global.player_pushbox_right == true):
			animPlayer.play("hero_push_idle")

	if state == ON_FLOOR or state == SITDOWN:
		if dir_look == true: 
			anim.flip_h = false
			if turn_around_left == true:
				state = TURN_AROUND_LEFT
			if collision_sitdown:
				$Head.disabled = true
				state = SITDOWN
			raycast_up.target_position.x = 20
			raycast_down.target_position.x = 20
			raycast_hands_coll.target_position.x = 70
			$AttackDirection.rotation_degrees = 0
			raycast_hero_push_coll.target_position.x = 20
		elif dir_look == false: 
			anim.flip_h = true
			if turn_around_right == true:
				state = TURN_AROUND_RIGHT
			if collision_sitdown:
				$Head.disabled = true
				state = SITDOWN
			$AttackDirection.rotation_degrees = 180
			raycast_up.target_position.x = -20
			raycast_down.target_position.x = -20
			raycast_hands_coll.target_position.x = -70
			raycast_hero_push_coll.target_position.x = -20

	if direction > 0:
		dir_look = true
	elif direction < 0:
		dir_look = false

	if Input.is_action_pressed("run") and state == ON_FLOOR:
		RUN_SPEED = 2
		if velocity.x != 0 or velocity.y != 0:
			Signals.emit_signal('player_run_speed_update', RUN_SPEED)
	elif state == ON_PUSH:
		RUN_SPEED = 0.2
	else:
		RUN_SPEED = 1
		if velocity.x != 0 or velocity.y != 0:
			Signals.emit_signal('player_run_speed_update', RUN_SPEED)

func on_walljump():
	await get_tree().create_timer(0.4).timeout
	state = IN_AIR

func jump() -> void:
	if climbing_lock: # прыжок тоже блокируем на время подъёма
		return
	if Input.is_action_just_pressed("jump") and state != ON_CLIMBING:
		if state == ON_FLOOR:
			velocity.y = -JUMP_POWER
			_play_jump_sfx()
			if velocity.y > 0:
				animPlayer.play('fall')
			elif velocity.y < 0:
				animPlayer.play('jump')

		if state == ON_WALL: 
			if Input.is_action_pressed("right") and Input.is_action_just_pressed("jump") and raycast_up.target_position.x == -20:
				velocity.y = -lerp(velocity.y, 650.0, 0.6)
				velocity.x = lerp(velocity.x, 350.0, 0.6)
				anim.flip_h = false
				raycast_up.target_position.x = 20
				raycast_hero_push_coll.target_position.x = 20
				raycast_down.target_position.x = 20
				raycast_hands_coll.target_position.x = 70
				$AttackDirection.rotation_degrees = 0
				state = IN_AIR
				animPlayer.play("jump_hands")
				await animPlayer.animation_finished

			if Input.is_action_pressed("left") and Input.is_action_just_pressed("jump") and raycast_up.target_position.x == 20:
				velocity.y = -lerp(velocity.y, 650.0, 0.6)		
				velocity.x = lerp(velocity.x, -350.0, 0.6)
				anim.flip_h = true
				$AttackDirection.rotation_degrees = 180
				raycast_hero_push_coll.target_position.x = -20
				raycast_up.target_position.x = -20
				raycast_down.target_position.x = -20
				raycast_hands_coll.target_position.x = -70
				state = IN_AIR
				animPlayer.play("jump_hands")
				await animPlayer.animation_finished

func block_state():
	velocity.x = move_toward(velocity.x, 0, float(MOVE_SPEED) / 20)
	animPlayer.play('block')

func slide_state():
	velocity.x = move_toward(velocity.x, 0, float(MOVE_SPEED) / 40)
	animPlayer.play("slide")
	await animPlayer.animation_finished
	velocity.x = move_toward(velocity.x, float(MOVE_SPEED), MOVE_SPEED * 2)
	state = ON_FLOOR

func attack_state():
	damage_multiplier = 1
	if Input.is_action_just_pressed('attack') and combo == true:
		state = ATTACK2
	velocity.x = move_toward(velocity.x, 0, float(MOVE_SPEED) / 20)
	animPlayer.play("attack")
	await animPlayer.animation_finished
	attack_freeze()
	state = ON_FLOOR

func attack2_state():
	damage_multiplier = 1.2
	if Input.is_action_just_pressed('attack') and combo == true:
		state = ATTACK3
	animPlayer.play("attack2")
	await animPlayer.animation_finished
	state = ON_FLOOR

func attack3_state():
	damage_multiplier = 2
	animPlayer.play("attack3")
	await animPlayer.animation_finished
	state = ON_FLOOR

func combo1():
	combo = true
	await animPlayer.animation_finished
	combo = false

func attack_freeze():
	attack_cooldown = true
	await get_tree().create_timer(0.5).timeout
	attack_cooldown = false

func sitdown_state():
	MOVE_SPEED = 40
	$Head.disabled = true

func _on_sitdown_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Platform"):
		collision_sitdown = true

func _on_sitdown_area_body_exited(_body: Node2D) -> void:
	collision_sitdown = false

func climb():
	if Input.is_action_pressed("up"):
		state = ON_CLIMBING
		climbing_up()
		if climbing_lock: # climbing_up() реально запустил подъём - не затираем его анимацию "висением"
			return
	
	velocity.x = 0
	ledge_testing = true
	if raycast_up.target_position.x == -20:
		anim.flip_h = true
	elif raycast_up.target_position.x == 20:
		anim.flip_h = false
	animPlayer.play("climbing")
	await animPlayer.animation_finished
	climb_on = true

func climbing_up():
	if climbing_lock: # уже поднимаемся - игнорируем повторные вызовы, пока корутина не завершилась
		return

	climb_on = false
	_play_climb_sfx()
		
	if raycast_up.target_position.x == 20 and Input.is_action_just_pressed("up"):
		climbing_lock = true
		state = ON_CLIMBING 
		velocity = Vector2.ZERO
		_play_climb_sfx()
		animPlayer.play("new_climbung_ledge_up")
		await animPlayer.animation_finished # сначала полностью доигрывает анимация
		global_position = Vector2(ledge_right_posx, ledge_right_posy) # потом мгновенный телепорт на место
		state = ON_FLOOR
		anim.flip_h = false
		turn_around_left = false
		turn_around_right = true
	elif raycast_up.target_position.x == -20 and Input.is_action_pressed("up"):
		climbing_lock = true
		state = ON_CLIMBING
		_play_climb_sfx()
		animPlayer.play("new_climbung_ledge_up")
		await animPlayer.animation_finished # сначала полностью доигрывает анимация
		position = Vector2(ledge_left_posx, ledge_left_posy) # потом мгновенный телепорт на место
		state = ON_FLOOR
		anim.flip_h = true
		turn_around_left = true
		turn_around_right = false
	else:
		return # ни одно условие не сработало - блокировку выставлять не за что

	is_on_ledge_down = false
	is_on_ledge_up = false # чтобы зацеп за стену не сработал заново на краю выступа
	climbing_lock = false # ввод разблокирован - подъём полностью завершён
	# state оставляем ON_FLOOR (выставлен в ветках выше) - НЕ откатываем в IN_AIR,
	# иначе update_state() снова поймает рейкаст выступа и утащит игрока в ON_WALL

func _on_barrier_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		is_near_barrier = true

func _on_barrier_area_body_exited(_body: Node2D) -> void:
	is_near_barrier = false

func break_barrier():
	$"../../wooden_wall/BarrierArea".visible = false
	break_timer = 0.0
	is_near_barrier = false

func _on_damage_received(enemy_damage):
	var was_on_ledge := state == ON_WALL or state == ON_CLIMBING or state == CLIMBING_DOWN
	if state == BLOCK:
		enemy_damage /= 2
	else:
		state = DAMAGE
	health -= enemy_damage
	emit_signal('health_changed', health)
	if was_on_ledge:
		drop_from_ledge_after_damage = true
		climb_on = false
		climbing_lock = false
		ledge_testing = false
		is_on_ledge_up = false
		is_on_ledge_down = false
		velocity.y = maxf(velocity.y, 140.0)
		velocity.x = 0
	state = DAMAGE

func on_damage():
	velocity.x = 0
	animPlayer.play("damage")
	await animPlayer.animation_finished
	if drop_from_ledge_after_damage:
		drop_from_ledge_after_damage = false
		state = IN_AIR
	else:
		state = ON_FLOOR

func _on_hit_box_area_entered(_area: Area2D) -> void:
	Signals.emit_signal('player_attack', damage_current)

func _enter_death_state() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	weapon.force_stop_shooting()
	weapon.visible = false
	_create_death_screen()


func _create_death_screen() -> void:
	var death_layer := CanvasLayer.new()
	death_layer.name = "DeathScreen"
	death_layer.layer = 100
	death_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(death_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.02, 0.025, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_layer.add_child(center)

	var message := Label.new()
	message.text = "МЁРТ\nНажмите любую клавишу"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 34)
	message.add_theme_color_override("font_color", Color(0.9, 0.82, 0.68, 1.0))
	message.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	message.add_theme_constant_override("outline_size", 8)
	center.add_child(message)


func _restart_after_death() -> void:
	if death_restart_requested:
		return
	death_restart_requested = true
	get_tree().reload_current_scene()

func _on_ledge_descent_right_body_entered(body: Node2D) -> void:
	if body.is_in_group("Platform"):
		descent_ledge_right = true

func _on_ledge_descent_right_body_exited(body: Node2D) -> void:
	if body.is_in_group("Platform"):
		descent_ledge_right = false

func _on_ledge_descent_left_body_entered(body: Node2D) -> void:
	if body.is_in_group("Platform"):
		descent_ledge_left = true

func _on_ledge_descent_left_body_exited(body: Node2D) -> void:
	if body.is_in_group("Platform"):
		descent_ledge_left = false

func _on_ledge_descent_center_body_exited(_body: Node2D) -> void:
	descent_ledge_center = false

func _on_ledge_descent_center_body_entered(_body: Node2D) -> void:
	descent_ledge_center = true

func _on_hero_back_area_body_entered(body: Node2D) -> void:
	if body.name == "Static_body_items":
		hero_back_coll_left = true
			
func _on_hero_back_area_body_exited(body: Node2D) -> void:
	if body.name == "Static_body_items":
		hero_back_coll_left = false
		
func _on_hero_back_area_left_right_body_entered(body: Node2D) -> void:
	if body.name == "Static_body_items":
		hero_back_coll_right = true

func _on_hero_back_area_left_right_body_exited(body: Node2D) -> void:
	if body.name == "Static_body_items":
		hero_back_coll_right = false

func _on_collision_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("Ladder"):
		ladder_position_x = area.global_position.x 
		Global.is_climbing = true
	if area.is_in_group("Water"):
		water_collision = true
		water_area1 = area.get_child(0).shape.get_rect().size.y / 2
		water_area2 = area.get_child(0).position.y + 30
		water_area3 = (water_area2 - water_area1)
		if !is_on_floor() and state != CLIMBING_DOWN and state != ON_WALL: 
			var tween = get_tree().create_tween()
			tween.tween_property(self, "position", Vector2(global_position.x, water_area3), 0.2)
			await tween.finished

func _on_collision_area_area_exited(area: Area2D) -> void:
	if area.is_in_group("Ladder"):
		Global.is_climbing = false
	if area.is_in_group("Water"):
		water_collision = false
		state = IN_AIR



func update_weapon_aim() -> void:
	# WeaponPivot находится под ArmsPivot и наследует его вращение от плеча.
	weapon_pivot.rotation = 0.0


func update_aim_rig() -> void:
	# Старый покадровый aiming больше не используется.
	aim_anim.visible = false
	if not weapon.visible:
		aim_rig.visible = false
		return

	aim_rig.visible = true

	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() < 0.001:
		return

	# Спрайты зеркалятся по горизонтали, поэтому вертикальный угол одинаков
	# для обеих сторон. Иначе при цели слева руки начинали смотреть вверх.
	# Near the player's center, keep the previous side so vertical mouse
	# movement cannot make the whole aiming rig flip back and forth.
	if absf(direction.x) > AIM_SIDE_DEADZONE:
		aim_facing_right = direction.x > 0.0
	var facing_right := aim_facing_right
	aim_arms_pivot.position = Vector2(
		aim_arms_pivot_default_position.x + (aim_arms_right_offset_x if facing_right else 0.0),
		aim_arms_pivot_default_position.y
	)
	aim_arms_sprite.flip_h = facing_right
	aim_arms_sprite.flip_v = false
	aim_head_sprite.flip_h = facing_right
	aim_body_sprite.flip_h = facing_right
	aim_arms_sprite.position.x = -aim_arms_default_position.x if facing_right else aim_arms_default_position.x
	aim_head_sprite.position.x = -aim_head_default_position.x if facing_right else aim_head_default_position.x
	weapon_pivot.position = Vector2(
		weapon_pivot_default_position.x if facing_right else -weapon_pivot_default_position.x,
		weapon_pivot_default_position.y
	)
	# Aim from the weapon pivot, not from the player's center. The weapon is
	# offset above the player, so using global_position made shots pass above
	# the cursor.
	var weapon_direction := get_global_mouse_position() - weapon_pivot.global_position
	if weapon_direction.length_squared() > 0.001:
		# Arms follow the same pivot-based angle as the weapon.
		var aim_angle := atan2(weapon_direction.y, absf(weapon_direction.x))
		# The left-facing hand sprite has the opposite vertical orientation.
		aim_arms_pivot.rotation = aim_angle if facing_right else -aim_angle
		var head_angle := aim_angle if facing_right else -aim_angle
		aim_head_pivot.rotation = clampf(head_angle, -0.65, 0.65)
		weapon_pivot.global_rotation = weapon_direction.angle()
	weapon.set_aim_facing(facing_right)

func can_player_shoot() -> bool:

	if state == ON_LADDER:
		return false

	if state == ON_CLIMBING:
		return false

	if state == CLIMBING_DOWN:
		return false

	if state == IN_WATER:
		return false

	if state == ON_WALL:
		return false

	if state == DAMAGE:
		return false

	if state == STRONG_FALL:
		return false

	# Запрещаем стрельбу во время всех ударов мечом
	if state == ATTACK:
		return false

	if state == ATTACK2:
		return false

	if state == ATTACK3:
		return false

	return true
	
func _input(event):
	if is_dead:
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			_restart_after_death()
		return

	if event.is_action_pressed("shoot"):

		if can_player_shoot():
			weapon.shoot()

	if event.is_action_pressed("reload"):
		weapon.reload()


func update_weapon_visibility():
	var can_show_weapon = true
	
	# Состояния, где оружие должно быть скрыто
	match state:
		ON_WALL, ON_CLIMBING, CLIMBING_DOWN, ON_LADDER, IN_WATER, STRONG_FALL, DAMAGE, ON_PUSH:
			can_show_weapon = false
		# Убираем SITDOWN из списка - оружие должно быть видно
	
	# Если оружие должно быть скрыто - принудительно останавливаем стрельбу
	if not can_show_weapon:
		weapon.force_stop_shooting()
		weapon.visible = false
	else:
		weapon.visible = true
