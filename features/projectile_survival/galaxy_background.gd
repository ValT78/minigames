extends Node2D

# Les positions normalisées permettent au ciel de suivre les redimensionnements.
var _star_positions: Array[Vector2] = []
var _star_sizes: Array[float] = []


func _ready() -> void:
	# Une graine fixe évite que le fond change à chaque nouvelle manche.
	var random := RandomNumberGenerator.new()
	random.seed = 73421
	for star_index in 180:
		_star_positions.append(Vector2(random.randf(), random.randf()))
		_star_sizes.append(random.randf_range(0.7, 2.2))
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func _exit_tree() -> void:
	# Le fond peut être retiré entre deux mini-jeux par le futur GameManager.
	if get_viewport().size_changed.is_connected(queue_redraw):
		get_viewport().size_changed.disconnect(queue_redraw)


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("050617"))

	# Trois bandes diagonales superposées suggèrent le volume de la Voie lactée.
	_draw_galaxy_band(viewport_size, 410.0, Color(0.18, 0.16, 0.42, 0.16))
	_draw_galaxy_band(viewport_size, 250.0, Color(0.32, 0.27, 0.58, 0.13))
	_draw_galaxy_band(viewport_size, 105.0, Color(0.73, 0.65, 0.92, 0.09))

	# Les petits points restent discrets pour ne pas être confondus avec les joueurs.
	for star_index in _star_positions.size():
		var star_position := _star_positions[star_index] * viewport_size
		var brightness := 0.35 + 0.45 * _star_sizes[star_index] / 2.2
		draw_circle(
			star_position,
			_star_sizes[star_index],
			Color(0.78, 0.84, 1.0, brightness),
		)


func _draw_galaxy_band(viewport_size: Vector2, width: float, color: Color) -> void:
	# La bande dépasse largement l'écran afin de couvrir tous les formats d'affichage.
	var center := viewport_size * 0.5
	var direction := Vector2(1.0, -0.43).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var half_length := viewport_size.length()
	var half_width := width * 0.5
	draw_colored_polygon(
		PackedVector2Array([
			center - direction * half_length - normal * half_width,
			center + direction * half_length - normal * half_width,
			center + direction * half_length + normal * half_width,
			center - direction * half_length + normal * half_width,
		]),
		color,
	)
