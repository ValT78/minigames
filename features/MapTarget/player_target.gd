extends Node2D

var _input : LocalPlayer
var country : String
@export var _speed : float

func setup(input : LocalPlayer) :
	get_child(0).self_modulate = input.color
	_input = input
	
func _physics_process(delta: float) -> void:
	if not _input : return
	global_position += _input.input.direction * _speed
	
	if _input.input.action_1_just_pressed :
		print(country)
		if get_parent().country == country :
			GameManager.minigameWon(_input.id)
		
