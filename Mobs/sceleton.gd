extends CharacterBody2D


var chase = false
var speed = 50
@onready var anim = $AnimatedSprite2D
var alive = true
var attack = false


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	var player = $"../../Player/Player"
	
	var direction = (player.position - self.position).normalized()
	if alive == true and attack != true:
	
		if chase == true:
			velocity.x = direction.x * speed
			anim.play('walk')
		else:
			velocity.x = 0
			anim.play('idle')
		if direction.x < 0:
			$AnimatedSprite2D.flip_h = true
		elif direction.x > 0:
			$AnimatedSprite2D.flip_h = false
	if attack == true:
		anim.play('attack')
		await anim.animation_finished
	move_and_slide()


func _on_area_2d_body_entered(body: Node2D) -> void:
	#print(body.name)
	if body.name == "Player":
		chase = true
		
		



func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		chase = false


func _on_dead_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		body.velocity.y -= 300
		
		dead()

func dead():
	#alive = false
	#velocity.x = 0
	chase = false
	anim.play('dead')
	await anim.animation_finished
	queue_free()


func _on_dead_2_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		if alive == true:
			#body.health -= 40
			velocity.x = 0
		dead()
	if body.is_in_group("wall"):
		attack = true
		print("Сломать стену")
		
func _on_dead_body_exited(body: Node2D) -> void:
	pass


func _on_dead_2_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		chase = true	
	if body.is_in_group("wall"):
		attack = false
