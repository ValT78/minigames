extends RigidBody2D

var power : float = 700
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var randomAngle : float = randf() * 2 * 3.1415
	linear_velocity = Vector2(cos(randomAngle),sin(randomAngle)) * power
