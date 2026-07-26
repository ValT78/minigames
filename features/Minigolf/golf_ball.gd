extends RigidBody2D
class_name GolfBall

var _input : LocalPlayer
@export var _speed : float
@onready var arrow: Node2D = $arrow
const velocityThresshold = 15000
@onready var audio_player_colision: AudioStreamPlayer2D = $AudioPlayerColision
@onready var audio_player_impact: AudioStreamPlayer2D = $AudioPlayerImpact


func setup(input : LocalPlayer) :
	modulate = input.color
	_input = input
	
func _physics_process(delta: float) -> void:
	if not _input : return
	
	if linear_velocity.length_squared() > velocityThresshold : 
		arrow.modulate.a =  0.25
	else :
		arrow.modulate.a =  1
	
	arrow.rotation_degrees += _input.input.direction.x * _speed * delta * 40 * (2 if _input.input.action_2_pressed else 1)
	if arrow.rotation_degrees > 360 : arrow.rotation_degrees -= 360
	elif arrow.rotation_degrees < 0 : arrow.rotation_degrees += 360
	
	arrow.scale.x = max(0.3,min(1,
		arrow.scale.x - _input.input.direction.y * _speed * delta
		 * (2 if _input.input.action_2_pressed else 1)))
	
	if _input.input.action_1_just_pressed :
		print(linear_velocity.length_squared())
		if linear_velocity.length_squared() < velocityThresshold :
			apply_force(Vector2(cos(arrow.global_rotation),sin(arrow.global_rotation))*100 * arrow.scale.x)
		

func _on_body_entered(body: Node) -> void:
	if not audio_player_colision : return
	if body.is_in_group("ball") :
		audio_player_colision.play()
	else :
		audio_player_impact.play()
