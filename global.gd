extends Node


var player_visibility = false
var player_on_visibility_area = false

#для лестницы
var is_climbing = false

var ladder_xpos


var box_player_collision = false
var player_pushbox_left = true
var player_pushbox_right = false
var push_onoff = false


func _process(_delta: float) -> void:
	if player_visibility == true:
		#print('ВАС ЗАМЕТИЛИ')
		pass
