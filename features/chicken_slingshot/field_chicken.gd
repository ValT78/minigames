class_name FieldChicken
extends Area2D

signal killed(player_id: int)

# Une faible vitesse laisse aux tirs chargés le temps de rester prévisibles.
@export var movement_speed_min := 54.0
@export var movement_speed_max := 82.0
@export var body_radius := 31.0

@onready var chicken_visual: Node2D = %ChickenVisual
@onready var collision_shape: CollisionShape2D = %CollisionShape2D

# La poule choisit une dérive unique puis rebondit dans le champ.
var _field_rect := Rect2()
var _movement_velocity := Vector2.ZERO
var _alive := true
var _movement_enabled := true


func setup(spawn_position: Vector2, field_rect: Rect2) -> void:
	position = spawn_position
	_field_rect = field_rect
	var movement_direction := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if movement_direction.length_squared() <= 0.05:
		movement_direction = Vector2.RIGHT
	_movement_velocity = movement_direction.normalized() * randf_range(
		movement_speed_min,
		movement_speed_max,
	)


func _physics_process(delta: float) -> void:
	if not _alive or not _movement_enabled:
		return

	# Les rebonds conservent toutes les cibles disponibles jusqu'à la fin du timer.
	position += _movement_velocity * delta
	if position.x <= _field_rect.position.x + body_radius:
		position.x = _field_rect.position.x + body_radius
		_movement_velocity.x = absf(_movement_velocity.x)
	elif position.x >= _field_rect.end.x - body_radius:
		position.x = _field_rect.end.x - body_radius
		_movement_velocity.x = -absf(_movement_velocity.x)
	if position.y <= _field_rect.position.y + body_radius:
		position.y = _field_rect.position.y + body_radius
		_movement_velocity.y = absf(_movement_velocity.y)
	elif position.y >= _field_rect.end.y - body_radius:
		position.y = _field_rect.end.y - body_radius
		_movement_velocity.y = -absf(_movement_velocity.y)

	# Le visuel regarde grossièrement dans le sens horizontal de sa marche.
	chicken_visual.scale.x = 1.0 if _movement_velocity.x >= 0.0 else -1.0


func try_kill(player_id: int) -> bool:
	if not _alive:
		return false
	_alive = false
	_movement_velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)
	killed.emit(player_id)

	# Une courte disparition rend l'impact lisible avant de libérer la cible.
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(chicken_visual, "rotation", chicken_visual.rotation + PI, 0.2)
	death_tween.tween_property(chicken_visual, "scale", Vector2(0.15, 0.15), 0.2)
	death_tween.tween_property(chicken_visual, "modulate:a", 0.0, 0.2)
	death_tween.chain().tween_callback(queue_free)
	return true


func set_field_rect(field_rect: Rect2) -> void:
	_field_rect = field_rect
	position.x = clampf(position.x, _field_rect.position.x + body_radius, _field_rect.end.x - body_radius)
	position.y = clampf(position.y, _field_rect.position.y + body_radius, _field_rect.end.y - body_radius)


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
