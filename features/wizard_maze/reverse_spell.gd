class_name ReverseSpell
extends Node2D

@export var travel_speed := 1050.0
@export var reverse_duration := 1.25

var _caster_player_id := -1
var _travel_direction := Vector2.RIGHT
var _maximum_distance := 600.0
var _traveled_distance := 0.0
var _targets: Array[WizardHat] = []
var _spell_color := Color("d987ff")


func setup(
	caster_player_id: int,
	direction: Vector2,
	spell_color: Color,
	targets: Array[WizardHat],
	maximum_distance: float,
) -> void:
	# Le projectile reçoit une copie des cibles de la manche et ignore toute géométrie de mur.
	_caster_player_id = caster_player_id
	_travel_direction = direction.normalized()
	_spell_color = spell_color
	_targets = targets
	_maximum_distance = maximum_distance
	rotation = _travel_direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	# Aucun move_and_collide n'est utilisé : le sort traverse volontairement tous les murs.
	var travel_step := travel_speed * delta
	global_position += _travel_direction * travel_step
	_traveled_distance += travel_step
	rotation += delta * 7.0
	_check_hat_hits()
	if _traveled_distance >= _maximum_distance:
		queue_free()


func _check_hat_hits() -> void:
	# Une simple distance suffit car il n'existe que deux chapeaux dans le backbone actuel.
	for target in _targets:
		if not is_instance_valid(target) or target.get_player_id() == _caster_player_id:
			continue
		if global_position.distance_to(target.global_position) > target.get_hit_radius() + 12.0:
			continue
		target.apply_reverse_controls(reverse_duration)
		queue_free()
		return


func _draw() -> void:
	# Une étoile violette très contrastée reste visible au-dessus des murs de pierre.
	draw_circle(Vector2.ZERO, 15.0, Color(_spell_color, 0.2), true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(18, 0),
			Vector2(7, 5),
			Vector2(8, 16),
			Vector2(0, 8),
			Vector2(-9, 15),
			Vector2(-7, 5),
			Vector2(-18, 0),
			Vector2(-7, -5),
			Vector2(-9, -15),
			Vector2(0, -8),
			Vector2(8, -16),
			Vector2(7, -5),
		]),
		_spell_color,
	)
	draw_circle(Vector2.ZERO, 5.0, Color("fff3bf"), true)
