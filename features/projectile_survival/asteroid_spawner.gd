class_name AsteroidSpawner
extends Node

# La courbe va d'un astéroïde lisible à des vagues nombreuses en fin de manche.
@export var initial_wave_interval := 1.25
@export var final_wave_interval := 0.42
@export var warning_duration := 0.45
@export var initial_asteroid_speed := 360.0
@export var final_asteroid_speed := 650.0

const ASTEROID_SCENE := preload("res://features/projectile_survival/asteroid.tscn")
const WARNING_MARKER_SCENE := preload("res://features/projectile_survival/warning_marker.tscn")

# Ces références sont fournies par la scène principale pour garder le générateur réutilisable.
var _arena_rect := Rect2()
var _round_duration := 20.0
var _elapsed_time := 0.0
var _time_until_next_wave := 0.6
var _asteroid_container: Node2D
var _running := false
var _generation_id := 0


func setup(arena_rect: Rect2, round_duration: float, asteroid_container: Node2D) -> void:
	_arena_rect = arena_rect
	_round_duration = maxf(round_duration, 0.1)
	_asteroid_container = asteroid_container
	_elapsed_time = 0.0
	_time_until_next_wave = 0.65
	_running = true
	_generation_id += 1


func _physics_process(delta: float) -> void:
	if not _running or _asteroid_container == null:
		return

	# La progression relative conserve la même montée en puissance pour toute durée choisie.
	_elapsed_time += delta
	_time_until_next_wave -= delta
	if _time_until_next_wave > 0.0:
		return

	var difficulty := clampf(_elapsed_time / _round_duration, 0.0, 1.0)
	_spawn_wave(difficulty)
	_time_until_next_wave = lerpf(
		initial_wave_interval,
		final_wave_interval,
		pow(difficulty, 1.25),
	)


func _spawn_wave(difficulty: float) -> void:
	# Les paliers rendent l'augmentation du nombre immédiatement perceptible.
	var asteroid_count := 1
	if difficulty >= 0.35:
		asteroid_count = 2
	if difficulty >= 0.72:
		asteroid_count = 3

	for asteroid_index in asteroid_count:
		var launch_data := _create_launch_data(difficulty, asteroid_index)
		_warn_then_launch(launch_data, _generation_id)


func _create_launch_data(difficulty: float, asteroid_index: int) -> Dictionary:
	# Chaque danger traverse l'arène depuis un bord vers une zone opposée.
	var side := randi_range(0, 3)
	var spawn_padding := 54.0
	var spawn_position := Vector2.ZERO
	match side:
		0:
			spawn_position = Vector2(
			randf_range(_arena_rect.position.x, _arena_rect.end.x),
			_arena_rect.position.y - spawn_padding,
		)
		1:
			spawn_position = Vector2(
			_arena_rect.end.x + spawn_padding,
			randf_range(_arena_rect.position.y, _arena_rect.end.y),
		)
		2:
			spawn_position = Vector2(
			randf_range(_arena_rect.position.x, _arena_rect.end.x),
			_arena_rect.end.y + spawn_padding,
		)
		_:
			spawn_position = Vector2(
			_arena_rect.position.x - spawn_padding,
			randf_range(_arena_rect.position.y, _arena_rect.end.y),
		)

	# Une cible centrale élargie produit des trajectoires variées mais toujours utiles.
	var target_margin := 90.0
	var target_rect := _arena_rect.grow(-target_margin)
	var target_position := Vector2(
		randf_range(target_rect.position.x, target_rect.end.x),
		randf_range(target_rect.position.y, target_rect.end.y),
	)
	var travel_direction := spawn_position.direction_to(target_position)
	var base_speed := lerpf(initial_asteroid_speed, final_asteroid_speed, difficulty)
	return {
		"position": spawn_position,
		"direction": travel_direction,
		"speed": base_speed * randf_range(0.88, 1.12),
		"radius": randf_range(19.0, 39.0),
		"rotation_speed": randf_range(-2.4, 2.4) + float(asteroid_index) * 0.05,
	}


func _warn_then_launch(launch_data: Dictionary, generation_id: int) -> void:
	# Le marqueur laisse au joueur le temps de comprendre chaque nouvelle trajectoire.
	var warning_marker: AsteroidWarningMarker = WARNING_MARKER_SCENE.instantiate()
	_asteroid_container.add_child(warning_marker)
	warning_marker.setup(
		launch_data["position"],
		launch_data["direction"],
		warning_duration,
	)
	await warning_marker.finished
	if not _running or generation_id != _generation_id or not is_instance_valid(_asteroid_container):
		return

	# L'astéroïde reprend exactement la position et l'orientation annoncées.
	var asteroid: SurvivalAsteroid = ASTEROID_SCENE.instantiate()
	_asteroid_container.add_child(asteroid)
	asteroid.position = launch_data["position"]
	asteroid.setup(
		launch_data["direction"],
		launch_data["speed"],
		launch_data["radius"],
		launch_data["rotation_speed"],
		_arena_rect,
	)


func set_arena_rect(arena_rect: Rect2) -> void:
	_arena_rect = arena_rect


func stop() -> void:
	# Changer l'identifiant invalide aussi les lancements encore en attente.
	_running = false
	_generation_id += 1
