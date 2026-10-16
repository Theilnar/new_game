extends RigidBody2D

var is_magazine: bool = false

func _ready() -> void:
	add_to_group("weapon_debris")
	collision_layer = 0
	collision_mask = 1
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	mass = 0.12 if is_magazine else 0.01
	linear_damp = 0.25
	angular_damp = 1.5
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.15 if is_magazine else 0.35
	physics_material_override.friction = 0.8
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(5, 12) if is_magazine else Vector2(5, 2)
	collider.shape = rectangle
	add_child(collider)
	var tween := create_tween()
	tween.tween_interval(18.0 if is_magazine else 12.0)
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

func _draw() -> void:
	if is_magazine:
		draw_rect(Rect2(-2.5, -6, 5, 12), Color("252b33"))
		draw_rect(Rect2(-1.5, -5, 1, 9), Color("707b89"))
		draw_rect(Rect2(-3.5, 4, 7, 2), Color("14191f"))
	else:
		draw_rect(Rect2(-2.5, -1, 5, 2), Color("c89b44"))
		draw_line(Vector2(-2, -1), Vector2(2, -1), Color("ffe09a"))
		draw_line(Vector2(-2, -1), Vector2(-2, 1), Color("8c6229"))
