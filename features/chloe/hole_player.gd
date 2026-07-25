extends Node2D

var _input : LocalPlayer
@export var _speed : float
@onready var label: Label = $Label

var score : int = 0
var maxScore : int = 5

func _ready() :
	print(label)
	label.text = str(score," / ",maxScore)

func setup(input : LocalPlayer) :
	get_child(0).self_modulate = input.color
	_input = input
	
func _physics_process(delta: float) -> void:
	if not _input : return
	global_position += _input.input.direction * _speed * delta * 40
		
func _on_body_entered(body: Node2D) -> void:
	print(body)
	if not body.is_in_group("ball") : return
	body.queue_free()
	score += 1
	label.text = str(score," / ",maxScore)
	if score == maxScore :
		GameManager.minigameWon(_input.id)
