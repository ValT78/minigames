extends RigidBody2D

@onready var audio_player_colision: AudioStreamPlayer2D = $AudioPlayerColision
@onready var audio_player_impact: AudioStreamPlayer2D = $AudioPlayerImpact

var power : float = 700
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var randomAngle : float = randf() * 2 * 3.1415
	linear_velocity = Vector2(cos(randomAngle),sin(randomAngle)) * power


func _on_body_entered(body: Node) -> void:
	if not audio_player_colision : return
	if body.is_in_group("ball") :
		audio_player_colision.play()
	else :
		audio_player_impact.play()
