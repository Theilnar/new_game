extends Node2D
class_name LaserGun

@export_category("Laser")
@export var laser_color: Color = Color("35E8FF")
@export var core_color: Color = Color.WHITE
@export var max_distance: float = 1400.0
@export var laser_duration: float = 0.09
@export var laser_width: float = 5.0
@export var core_width: float = 1.8

@export_category("Muzzle Flash")
@export var flash_duration: float = 0.08

@export_category("Hit")
@export var hit_enabled: bool = true
@export var hit_duration: float = 0.16

@onready var laser_outer: Line2D = $LaserOuter
@onready var laser_mid: Line2D = $LaserMid
@onready var laser_core: Line2D = $LaserCore
@onready var muzzle: PointLight2D = $MuzzleLight
@onready var hit_light: PointLight2D = $HitLight

var _laser_tween: Tween
var _muzzle_tween: Tween
var _hit_tween: Tween

func _ready() -> void:
    _setup_visuals()
    _hide_all()

func _setup_visuals() -> void:
    laser_outer.width = laser_width * 3.0
    laser_mid.width = laser_width
    laser_core.width = core_width
    laser_outer.default_color = Color(laser_color, 0.22)
    laser_mid.default_color = Color(laser_color, 0.92)
    laser_core.default_color = core_color

    var additive := CanvasItemMaterial.new()
    additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    laser_outer.material = additive
    laser_mid.material = additive
    laser_core.material = additive

    muzzle.color = laser_color
    hit_light.color = laser_color

func _hide_all() -> void:
    laser_outer.visible = false
    laser_mid.visible = false
    laser_core.visible = false
    muzzle.visible = false
    hit_light.visible = false

func shoot(target_global_position: Vector2) -> void:
    var direction := target_global_position - global_position
    if direction.length_squared() < 0.001:
        direction = Vector2.RIGHT.rotated(global_rotation)
    direction = direction.normalized()

    var distance: float = minf(global_position.distance_to(target_global_position), max_distance)
    var end_global: Vector2 = global_position + direction * distance

    var space := get_world_2d().direct_space_state
    var query := PhysicsRayQueryParameters2D.create(global_position, end_global)
    query.exclude = [self]
    var hit := space.intersect_ray(query)

    if not hit.is_empty():
        end_global = hit.position

    var end_local := to_local(end_global)
    var points := PackedVector2Array([Vector2.ZERO, end_local])
    laser_outer.points = points
    laser_mid.points = points
    laser_core.points = points

    _show_laser()
    _show_muzzle()

    if hit_enabled and not hit.is_empty():
        _show_hit(hit.position)

func shoot_in_direction(direction: Vector2, distance: float = -1.0) -> void:
    if direction.length_squared() < 0.001:
        return
    var dist: float = max_distance if distance <= 0.0 else minf(distance, max_distance)
    shoot(global_position + direction.normalized() * dist)

func _show_laser() -> void:
    if _laser_tween and _laser_tween.is_valid():
        _laser_tween.kill()

    laser_outer.visible = true
    laser_mid.visible = true
    laser_core.visible = true
    laser_outer.modulate.a = 0.0
    laser_mid.modulate.a = 0.0
    laser_core.modulate.a = 0.0

    _laser_tween = create_tween().set_parallel(true)
    _laser_tween.tween_property(laser_outer, "modulate:a", 1.0, 0.012)
    _laser_tween.tween_property(laser_mid, "modulate:a", 1.0, 0.012)
    _laser_tween.tween_property(laser_core, "modulate:a", 1.0, 0.008)
    _laser_tween.chain().tween_interval(laser_duration * 0.45)
    _laser_tween.chain().tween_property(laser_outer, "modulate:a", 0.0, laser_duration * 0.55)
    _laser_tween.chain().tween_property(laser_mid, "modulate:a", 0.0, laser_duration * 0.55)
    _laser_tween.chain().tween_property(laser_core, "modulate:a", 0.0, laser_duration * 0.55)
    _laser_tween.chain().tween_callback(_hide_laser)

func _hide_laser() -> void:
    laser_outer.visible = false
    laser_mid.visible = false
    laser_core.visible = false

func _show_muzzle() -> void:
    if _muzzle_tween and _muzzle_tween.is_valid():
        _muzzle_tween.kill()
    muzzle.visible = true
    muzzle.energy = 0.0
    muzzle.texture_scale = 0.15

    _muzzle_tween = create_tween().set_parallel(true)
    _muzzle_tween.tween_property(muzzle, "energy", 3.8, 0.015)
    _muzzle_tween.tween_property(muzzle, "texture_scale", 1.0, 0.02)
    _muzzle_tween.chain().tween_property(muzzle, "energy", 0.0, flash_duration)
    _muzzle_tween.chain().tween_property(muzzle, "texture_scale", 0.1, flash_duration)
    _muzzle_tween.chain().tween_callback(func(): muzzle.visible = false)

func _show_hit(hit_position: Vector2) -> void:
    if _hit_tween and _hit_tween.is_valid():
        _hit_tween.kill()
    hit_light.global_position = hit_position
    hit_light.visible = true
    hit_light.energy = 0.0
    hit_light.texture_scale = 0.1

    _hit_tween = create_tween().set_parallel(true)
    _hit_tween.tween_property(hit_light, "energy", 3.0, 0.02)
    _hit_tween.tween_property(hit_light, "texture_scale", 0.9, 0.03)
    _hit_tween.chain().tween_property(hit_light, "energy", 0.0, hit_duration)
    _hit_tween.chain().tween_property(hit_light, "texture_scale", 0.1, hit_duration)
    _hit_tween.chain().tween_callback(func(): hit_light.visible = false)
