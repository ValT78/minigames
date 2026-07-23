class_name AsteroidWarningMarker
extends Node2D

signal finished

# Le marqueur dessine une flèche simple pointant vers la trajectoire future.
var _duration := 0.45
var _elapsed_time := 0.0
var _completed := false


func setup(spawn_position: Vector2, travel_direction: Vector2, duration: float) -> void:
	position = spawn_position
	rotation = travel_direction.angle()
	_duration = maxf(duration, 0.05)


func _process(delta: float) -> void:
	_elapsed_time += delta
	queue_redraw()
	if _elapsed_time >= _duration and not _completed:
		_completed = true
		finished.emit()
		queue_free()


func _draw() -> void:
	# Le clignotement devient plus rapide à l'approche de l'impact.
	var progress := clampf(_elapsed_time / _duration, 0.0, 1.0)
	var pulse := 0.45 + 0.55 * absf(sin(_elapsed_time * lerpf(14.0, 30.0, progress)))
	var warning_color := Color(1.0, 0.34, 0.19, pulse)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(22.0, 0.0),
			Vector2(-12.0, -15.0),
			Vector2(-12.0, 15.0),
		]),
		warning_color,
	)
	draw_line(Vector2(-10.0, 0.0), Vector2(-52.0, 0.0), warning_color, 5.0)
