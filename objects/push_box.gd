extends Node2D


var box_pos_x = 0

@onready var area_coll := $StaticBody2D/Area2D

var posbox = 0

func _physics_process(_delta: float) -> void:
	if Global.box_player_collision == true and Global.push_onoff == true:
		position.x = position.x + posbox
	#elif Global.push_onoff == false :
	#	position.x
	

func _ready() -> void:
	Signals.connect("box_push", Callable (self, "_box_push_position_x"))
	
	#Signals.connect("box_push", _on_custom_signal)

func _box_push_position_x(box_posx):
	posbox = box_posx
	#print(box_posx)
	#position.x +=box_posx
	
	
#func _physics_process(delta: float) -> void:
	#if area_coll.is_collising():
	#	var object = area_coll.get_collider()
		#box_push.emit(box_posx)
#	pass
		
#func _on_custom_signal() -> void:
#	print("Custom Signal sent")

	
func _on_area_2d_body_entered(body: Node2D) -> void:
	#if body.name == "Player":
		#Global.player_pushbox_left = true
		#$Panel.visible = true
	if body.is_in_group("Static_body_item"):
	#if body.name == "Static_body_items":
		Global.player_pushbox_left = false



func _on_area_2d_body_exited(body: Node2D) -> void:
	#if body.name == "Player":
		#Global.player_pushbox_left = false
		#$Panel.visible = false
	if body.is_in_group("Static_body_item"):
	#if body.name == "Static_body_items":
		Global.player_pushbox_left = true

func _on_area_2d_2_body_entered(body: Node2D) -> void:
	#if body.name == "Player":
		#Global.player_pushbox_right = true
		#$Panel.visible = true
	#if body.name == "Static_body_items":
	if body.is_in_group("Static_body_item"):
		Global.player_pushbox_right = true

func _on_area_2d_2_body_exited(body: Node2D) -> void:
	#if body.name == "Player":
		#Global.player_pushbox_right = false
		#$Panel.visible = false
	if body.is_in_group("Static_body_item"):
	#if body.name == "Static_body_items":
		Global.player_pushbox_right = false



func _on_player_coll_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		#print('player tut')
		Global.box_player_collision = true
		$Panel.visible = true

func _on_player_coll_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		Global.box_player_collision = false
		
		await get_tree().create_timer(0.5).timeout
		$Panel.visible = false
