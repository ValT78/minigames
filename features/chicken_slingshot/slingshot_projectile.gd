class_name SlingshotProjectile
extends Area2D

# Le caillou avance en ligne droite et sa distance dépend de la charge.
@export var rock_speed := 1500.0
@export var minimum_rock_distance := 320.0
@export var maximum_rock_distance := 1420.0
@export var arrow_speed := 2300.0

@onready var projectile_visual: Node2D = %ProjectileVisual
@onready var rock_visual: Polygon2D = %RockVisual
@onready var arrow_visual: Node2D = %ArrowVisual
@onready var rock_collision: CollisionShape2D = %RockCollision
@onready var arrow_collision: CollisionShape2D = %ArrowCollision

# Chaque instance conserve sa propre progression pour autoriser plusieurs tirs simultanés.
var _owner_player_id := 0
var _travel_direction := Vector2.RIGHT
var _maximum_distance := 700.0
var _travelled_distance := 0.0
var _is_arrow := false
var _cleanup_rect := Rect2()
var _consumed := false


func setup(
	owner_player_id: int,
	spawn_position: Vector2,
	travel_direction: Vector2,
	charge_ratio: float,
	is_arrow: bool,
	viewport_rect: Rect2,
) -> void:
	_owner_player_id = owner_player_id
	position = spawn_position
	_travel_direction = travel_direction.normalized()
	_is_arrow = is_arrow
	_cleanup_rect = viewport_rect.grow(220.0)
	_maximum_distance = lerpf(minimum_rock_distance, maximum_rock_distance, charge_ratio)
	_apply_projectile_mode()


func _ready() -> void:
	# Les poules sont des Area2D afin que les deux projectiles partagent le même contact.
	area_entered.connect(_on_area_entered)
	_apply_projectile_mode()


func _physics_process(delta: float) -> void:
	if _consumed:
		return

	if _is_arrow:
		_update_arrow(delta)
	else:
		_update_rock(delta)


func _update_rock(delta: float) -> void:
	# La portée chargée détruit uniquement cette instance, sans affecter les autres tirs.
	var movement_distance := rock_speed * delta
	position += _travel_direction * movement_distance
	_travelled_distance += movement_distance
	if _travelled_distance >= _maximum_distance:
		queue_free()


func _update_arrow(delta: float) -> void:
	# La flèche conserve une trajectoire rectiligne et traverse toutes les cibles.
	position += _travel_direction * arrow_speed * delta
	if not _cleanup_rect.has_point(position):
		queue_free()


func _apply_projectile_mode() -> void:
	if not is_node_ready():
		return

	# Une seule scène contient les deux collisions afin d'éviter deux scripts quasi identiques.
	rock_visual.visible = not _is_arrow
	arrow_visual.visible = _is_arrow
	rock_collision.disabled = _is_arrow
	arrow_collision.disabled = not _is_arrow
	rotation = _travel_direction.angle() if _is_arrow else 0.0


func _on_area_entered(area: Area2D) -> void:
	if _consumed or not area is FieldChicken:
		return
	var chicken := area as FieldChicken
	if not chicken.try_kill(_owner_player_id):
		return

	# Le caillou s'arrête au premier impact, contrairement à la flèche perforante.
	if not _is_arrow:
		_consumed = true
		set_deferred("monitoring", false)
		queue_free()
