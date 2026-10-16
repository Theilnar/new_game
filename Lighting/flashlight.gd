extends Node2D

@export_category("Flashlight")
@export var base_energy := 2.4
@export var flicker := 0.12
@export var light_color := Color(0.82, 0.91, 1.0, 1.0)
@export var texture_scale := 2.8
@export var aim_offset_degrees := -90.0

@onready var light: PointLight2D = $PointLight2D
var target_energy := 2.4
var flashlight_enabled := true


func _ready() -> void:
	light.color = light_color
	light.texture_scale = texture_scale
	target_energy = base_energy
	light.visible = true
	_build_light_occluders.call_deferred()

func _build_light_occluders() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null or scene_root.get_meta("light_occluders_built", false):
		return
	scene_root.set_meta("light_occluders_built", true)

	for shape_node in scene_root.find_children("*", "CollisionShape2D", true, false):
		var body := shape_node.get_parent()
		if not (body is StaticBody2D or body is RigidBody2D):
			continue
		var shape: Shape2D = shape_node.shape
		if shape is RectangleShape2D:
			var rectangle := shape as RectangleShape2D
			var half_size: Vector2 = rectangle.size * 0.5
			_add_occluder(body, PackedVector2Array([
				shape_node.position + Vector2(-half_size.x, -half_size.y),
				shape_node.position + Vector2(half_size.x, -half_size.y),
				shape_node.position + Vector2(half_size.x, half_size.y),
				shape_node.position + Vector2(-half_size.x, half_size.y)
			]))
		elif shape is CircleShape2D:
			var circle := shape as CircleShape2D
			var circle_points := PackedVector2Array()
			for index in range(16):
				circle_points.append(shape_node.position + Vector2.from_angle(TAU * index / 16.0) * circle.radius)
			_add_occluder(body, circle_points)

	for polygon_node in scene_root.find_children("*", "CollisionPolygon2D", true, false):
		var body := polygon_node.get_parent()
		if body is StaticBody2D or body is RigidBody2D:
			_add_occluder(body, polygon_node.polygon)

func _add_occluder(parent_node: Node, points: PackedVector2Array) -> void:
	if points.size() < 3:
		return
	var occluder := LightOccluder2D.new()
	occluder.occluder = OccluderPolygon2D.new()
	occluder.occluder.polygon = points
	parent_node.add_child(occluder)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		flashlight_enabled = not flashlight_enabled
		target_energy = base_energy if flashlight_enabled else 0.0


func _process(delta: float) -> void:
	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() > 0.001:
		# The flashlight texture points down in its default orientation.
		rotation = direction.angle() + deg_to_rad(aim_offset_degrees)

	if flashlight_enabled and randf() < 0.08:
		target_energy = base_energy + randf_range(-flicker, flicker)
	elif not flashlight_enabled:
		target_energy = 0.0
	light.energy = lerpf(light.energy, target_energy, delta * 12.0)
