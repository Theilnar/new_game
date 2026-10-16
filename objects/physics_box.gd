extends CharacterBody2D
class_name PhysicsBox

@export var weight := 2.5
@export var bullet_push_speed := 150.0
@export var player_push_speed := 48.0
@export var gravity := 1200.0
@export var horizontal_friction := 700.0
@export var movement_limits_enabled := false
@export var min_x := -1000000.0
@export var max_x := 1000000.0
@export var interaction_speed := 42.0

var interaction_active := false

func _ready() -> void:
	$BulletHitArea.body_entered.connect(_on_bullet_body_entered)
	$PlayerPushArea.body_entered.connect(_on_player_body_entered)
	$PlayerPushArea.body_exited.connect(_on_player_body_exited)
	$InteractArea.body_entered.connect(_on_interact_area_body_entered)
	$InteractArea.body_exited.connect(_on_interact_area_body_exited)

var player: CharacterBody2D
var angular_velocity := 0.0

func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and Input.is_action_just_pressed("interact"):
		interaction_active = not interaction_active

	if not is_on_floor():
		velocity.y += gravity * delta
		if absf(velocity.x) > 1.0:
			angular_velocity = move_toward(angular_velocity, signf(velocity.x) * 1.2, 2.0 * delta)
		rotation += angular_velocity * delta
	else:
		velocity.y = 0.0
		angular_velocity = move_toward(angular_velocity, 0.0, 8.0 * delta)
		rotation = lerp_angle(rotation, 0.0, 10.0 * delta)

	if interaction_active and is_instance_valid(player):
		var input_direction := Input.get_axis("left", "right")
		if absf(input_direction) > 0.0:
			velocity.x = input_direction * interaction_speed
			var player_is_left := player.global_position.x < global_position.x
			var pushing := (player_is_left and input_direction > 0.0) or (not player_is_left and input_direction < 0.0)
			if player.has_method("play_box_animation"):
				player.play_box_animation(&"push" if pushing else &"pull")
		else:
			velocity.x = move_toward(velocity.x, 0.0, horizontal_friction * delta)
			if player.has_method("play_box_animation"):
				player.play_box_animation(&"idle")
	else:
		velocity.x = move_toward(velocity.x, 0.0, horizontal_friction * delta)

	if movement_limits_enabled:
		var next_x := global_position.x + velocity.x * delta
		if next_x <= min_x or next_x >= max_x:
			velocity.x = 0.0
	move_and_slide()
	if movement_limits_enabled:
		global_position.x = clampf(global_position.x, min_x, max_x)

func _on_player_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body

func _on_player_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		interaction_active = false

func _on_interact_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_instance_valid(player):
		player = body

func _on_interact_area_body_exited(body: Node2D) -> void:
	if body == player:
		interaction_active = false


func _on_bullet_body_entered(body: Node2D) -> void:
	if body.is_in_group("projectile"):
		var direction: Variant = body.get("direction")
		if direction is Vector2:
			on_bullet_hit(direction, 0)

func on_bullet_hit(direction: Vector2, _damage: int) -> void:
	if direction.length_squared() <= 0.001:
		return
	var weight_factor := clampf(1.0 / weight, 0.15, 1.0)
	velocity.x += direction.normalized().x * bullet_push_speed * weight_factor
	velocity.x = clampf(velocity.x, -220.0, 220.0)
	angular_velocity += direction.normalized().x * 2.0 * weight_factor
