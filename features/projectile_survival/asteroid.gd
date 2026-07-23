class_name SurvivalAsteroid
extends Area2D

# Le déplacement est déterminé une seule fois par le générateur.
var _travel_direction := Vector2.RIGHT
var _travel_speed := 420.0
var _rotation_speed := 1.0
var _cleanup_rect := Rect2()


func setup(
	travel_direction: Vector2,
	travel_speed: float,
	asteroid_radius: float,
	rotation_speed: float,
	cleanup_rect: Rect2,
) -> void:
	# La scène de base mesure 56 pixels, donc son rayon de référence vaut 28.
	_travel_direction = travel_direction.normalized()
	_travel_speed = travel_speed
	_rotation_speed = rotation_speed
	_cleanup_rect = cleanup_rect.grow(260.0)
	scale = Vector2.ONE * asteroid_radius / 28.0


func _ready() -> void:
	# Le signal local maintient toute la logique de collision dans le projectile.
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# Les astéroïdes traversent l'écran sans guidage ni accélération cachée.
	position += _travel_direction * _travel_speed * delta
	rotation += _rotation_speed * delta
	if not _cleanup_rect.has_point(position):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Un astéroïde disparaît seulement lorsqu'il éteint réellement une étoile.
	if body is SurvivalStar and body.try_eliminate():
		queue_free()
