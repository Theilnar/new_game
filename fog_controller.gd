extends Node2D

@export var toggle_action: StringName = &"fog_toggle"
@export var fog_enabled: bool = true

var fog_nodes: Array[CanvasItem] = []


func _ready() -> void:
	for node in get_tree().get_nodes_in_group("screen_fog"):
		if node is CanvasItem:
			fog_nodes.append(node as CanvasItem)
	_set_fog_visible(fog_enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		fog_enabled = not fog_enabled
		_set_fog_visible(fog_enabled)
		get_viewport().set_input_as_handled()


func _set_fog_visible(enabled: bool) -> void:
	for fog_node in fog_nodes:
		if is_instance_valid(fog_node):
			fog_node.visible = enabled
