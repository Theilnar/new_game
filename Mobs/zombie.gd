extends CharacterBody2D

enum {
	IDLE,
	ATTACK,
	CHASE,
	DAMAGE,
	DEATH,
	RECOVER,
	RUN,
	JUMP
}

var state: int = 0:
	set(value):
		state = value
		match state:
			IDLE:
				idle_state()
			ATTACK:
				attack_state()
			DAMAGE:
				damage_state()
			RECOVER:
				recover_state()
			DEATH:
				death_state()
			RUN:
				run_state()
			JUMP:
				jump_state()

var player
var direction
var damage = 1
var health = 100
var speed = 100

@onready var animSprite = $AnimatedSprite2D
@onready var animPlayer = $AnimationPlayer

func _ready() -> void:
	#ignals.connect("player_position_update".Callable (self,''))
	Signals.connect("player_position_update", Callable (self, "_on_player_position_update"))
	Signals.connect("player_attack", Callable (self, "_on_damage_received"))
	
func _on_player_position_update(player_pos):
	player = player_pos
	#print(player)

func chase_state():
	direction = (player - self.position).normalized()
	#print(direction)
	if direction.x < 0:
		animSprite.flip_h = true
		$AttackDirecton.rotation_degrees = 180
		$VisionArea.rotation_degrees = 180
	else:
		animSprite.flip_h = false
		$AttackDirecton.rotation_degrees = 0
		$VisionArea.rotation_degrees = 0

	
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if state == CHASE:
		chase_state()
	move_and_slide()

func _on_attack_range_body_entered(_body: Node2D) -> void:
	state = ATTACK

func idle_state():
	animPlayer.play("idle")
	velocity.x = 0
	state = CHASE
	
func attack_state():
	animPlayer.play("attack")
	await animPlayer.animation_finished

	state = RECOVER
	
func jump_state():
	#direction = (player - self.position).normalized()
	#var min_speed = 1
	#var max_speed = 50
	#var jumpmove_height = 20
	#var max_distance = 100
	#var player_pos2 = player
	#var self_pos = get_global_position()        
	#var jump_distance = (player_pos2 - self_pos).normalized()
	#var distance_to_player = player_pos2.distance_to(self_pos)
		#
	#var horizontal_speed = min_speed + (distance_to_player / max_distance) * (max_speed - min_speed)
	#horizontal_speed = min(max_speed, max(min_speed, horizontal_speed))
		#
	#velocity = jump_distance 
	#velocity.x *= horizontal_speed * direction
	#velocity.y = -jumpmove_height #-jump_height
	print("jump")
	
	#velocity = move_and_slide(velocity, Vector2.UP)
	#velocity = move_and_slide(velocity,vector)
		
	#$Position2D/SlimeSkin/AnimationPlayer.play("SlimePrototype Attack")
	#$Jump_Cooldown.start()	
	
func run_state():
	direction = (player - self.position).normalized()
	animPlayer.play("run")
	print("ATTTACK")
	#direction = (player.position - self.position).normalized()
	if direction.x > 0:
		velocity.x = speed
	else:
		velocity.x -= speed
	chase_state()


func damage_state():
	animPlayer.play("damage")
	await animPlayer.animation_finished
	state = IDLE
	
func death_state():
	animPlayer.play('death')
	await animPlayer.animation_finished
	queue_free()
	
func recover_state():
	animPlayer.play('recover')
	await animPlayer.animation_finished
	state = IDLE

func _on_hit_box_area_entered(_area: Area2D) -> void:
	Signals.emit_signal('enemy_attack', damage)
	print('damage')

func _on_damage_received(player_damage):
	health -= player_damage
	print(player_damage)
	if health <= 0:
		state = DEATH
	else:
		state = IDLE
		state = DAMAGE
	


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		print("ATTTACK")
		state = RUN


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		state = IDLE


func _on_jump_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		print("JUMP")
		state = JUMP


func _on_jump_area_body_exited(body: Node2D) -> void:
	pass # Replace with function body.
