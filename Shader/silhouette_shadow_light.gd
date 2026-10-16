extends Sprite2D

## Передаёт позицию Light2D в silhouette_shadow.gdshader.
## Назначается вручную на Sprite2D с материалом тени.

@export var light_path: NodePath = NodePath("../../PointLight2D2")
@export var light_radius: float = 250.0
@export_range(0.0, 2.0, 0.01) var light_strength: float = 1.0
@export var energy_for_full_fade: float = 10.0

var _shadow_material: ShaderMaterial
var _light: Light2D

func _ready() -> void:
	_shadow_material = material as ShaderMaterial
	_light = get_node_or_null(light_path) as Light2D

	if _shadow_material == null:
		push_warning("silhouette_shadow_light.gd: у Sprite2D нет ShaderMaterial")
	if _light == null:
		push_warning("silhouette_shadow_light.gd: Light2D не найден по пути %s" % light_path)

func _process(_delta: float) -> void:
	if _shadow_material == null or _light == null:
		return

	_shadow_material.set_shader_parameter("light_position", _light.global_position)
	_shadow_material.set_shader_parameter("light_radius", light_radius)

	var energy_factor := clamp(_light.energy / max(energy_for_full_fade, 0.01), 0.0, 1.0)
	var active_factor := energy_factor if _light.visible else 0.0
	_shadow_material.set_shader_parameter("light_strength", active_factor * light_strength)
