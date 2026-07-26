extends Node2D

var _input : LocalPlayer
var country : String
@export var _speed : float
@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer
const DART = preload("uid://b4df3w0yre0dq")


func setup(input : LocalPlayer) :
	get_child(0).self_modulate = input.color
	_input = input
	
func _physics_process(delta: float) -> void:
	if not _input : return
	global_position += _input.input.direction * _speed * delta * 40
	if _input.input.action_1_just_pressed :
		audio_player.play()
		var dart : Node2D = DART.instantiate()
		dart.modulate = _input.color
		dart.global_position = global_position
		add_sibling(dart)
		var tween : Tween = create_tween()
		tween.tween_property(dart,"rotation",0.1,0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		if get_parent().country == country :
			GameManager.minigameWon(_input.id)
		
