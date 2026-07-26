extends Control


func _ready() -> void:
	# Le dessin s'adapte si la fenêtre change de taille avant son affichage.
	resized.connect(queue_redraw)


func _draw() -> void:
	var artwork_center := size * 0.5

	# Deux étoiles irrégulières donnent du volume à l'explosion sans texture dédiée.
	draw_colored_polygon(
		_create_burst(artwork_center, 345.0, 220.0, 18),
		Color("e94b22")
	)
	draw_colored_polygon(
		_create_burst(artwork_center, 260.0, 165.0, 18),
		Color("ffc83d")
	)
	draw_circle(artwork_center, 125.0, Color("fff1a6"))

	# Quelques morceaux anguleux rendent l'impact plus vivant autour de la bombe.
	_draw_debris(artwork_center + Vector2(-330.0, -95.0), -0.35, Color("ffcf5c"))
	_draw_debris(artwork_center + Vector2(315.0, -125.0), 0.45, Color("ff7043"))
	_draw_debris(artwork_center + Vector2(-280.0, 190.0), 0.25, Color("ff7043"))
	_draw_debris(artwork_center + Vector2(305.0, 175.0), -0.5, Color("ffcf5c"))

	# La fumée grise reste volontairement simple et lisible sur le fond sombre.
	_draw_smoke_cloud(artwork_center + Vector2(-210.0, -210.0), 0.9)
	_draw_smoke_cloud(artwork_center + Vector2(230.0, -185.0), 0.7)


func _create_burst(
	center: Vector2,
	outer_radius: float,
	inner_radius: float,
	point_count: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in point_count * 2:
		var point_angle := TAU * float(point_index) / float(point_count * 2)
		var point_radius := outer_radius if point_index % 2 == 0 else inner_radius
		points.append(center + Vector2.from_angle(point_angle) * point_radius)
	return points


func _draw_debris(center: Vector2, rotation_angle: float, color: Color) -> void:
	var local_points := PackedVector2Array([
		Vector2(-28.0, -12.0),
		Vector2(22.0, -18.0),
		Vector2(30.0, 13.0),
		Vector2(-16.0, 20.0),
	])
	var transformed_points := PackedVector2Array()
	for local_point in local_points:
		transformed_points.append(center + local_point.rotated(rotation_angle))
	draw_colored_polygon(transformed_points, color)


func _draw_smoke_cloud(center: Vector2, cloud_scale: float) -> void:
	var smoke_color := Color(0.48, 0.47, 0.44, 0.9)
	draw_circle(center + Vector2(-45.0, 12.0) * cloud_scale, 48.0 * cloud_scale, smoke_color)
	draw_circle(center + Vector2(0.0, -16.0) * cloud_scale, 61.0 * cloud_scale, smoke_color)
	draw_circle(center + Vector2(52.0, 10.0) * cloud_scale, 43.0 * cloud_scale, smoke_color)
