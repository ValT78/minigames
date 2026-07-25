class_name WizardMazeBoard
extends Node2D

# Les bits partagent exactement le format produit par WizardMazeGenerator.
const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

@export var wall_thickness := 10.0

@onready var wall_body: StaticBody2D = %WallBody

var _maze_data := {}
var _maze_origin := Vector2.ZERO
var _cell_size := 64.0
var _maze_rect := Rect2()


func setup(maze_data: Dictionary, available_rect: Rect2) -> void:
	# Le plateau conserve des cellules carrées et reste centré sous le HUD.
	_maze_data = maze_data
	var maze_pixel_size := Vector2(maze_data["width"], maze_data["height"])
	_cell_size = minf(
		available_rect.size.x / maze_pixel_size.x,
		available_rect.size.y / maze_pixel_size.y,
	)
	maze_pixel_size *= _cell_size
	_maze_origin = available_rect.get_center() - maze_pixel_size * 0.5
	_maze_rect = Rect2(_maze_origin, maze_pixel_size)
	_create_wall_collisions()
	queue_redraw()


func cell_to_world_center(cell: Vector2i) -> Vector2:
	# Le Node2D n'est pas déplacé, ses coordonnées locales correspondent au monde de la scène.
	return _maze_origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell_size


func world_to_cell(world_position: Vector2) -> Vector2i:
	# Le clamp garde une position proche de la bordure dans une cellule valide.
	var local_cell := Vector2i(floor((world_position.x - _maze_origin.x) / _cell_size), floor((world_position.y - _maze_origin.y) / _cell_size))
	return Vector2i(
		clampi(local_cell.x, 0, int(_maze_data["width"]) - 1),
		clampi(local_cell.y, 0, int(_maze_data["height"]) - 1),
	)


func is_cell_inside(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < int(_maze_data["width"])
		and cell.y < int(_maze_data["height"])
	)


func get_cell_size() -> float:
	return _cell_size


func get_exit_position() -> Vector2:
	return cell_to_world_center(_maze_data["exit_cell"])


func _create_wall_collisions() -> void:
	# Le plateau est régénéré en entier avant le début d'une manche.
	for previous_shape in wall_body.get_children():
		previous_shape.queue_free()

	# Chaque mur n'est créé qu'une fois : nord/ouest, puis les bordures sud/est.
	for cell_y in int(_maze_data["height"]):
		for cell_x in int(_maze_data["width"]):
			var cell := Vector2i(cell_x, cell_y)
			var openings: int = _maze_data["openings"][cell]
			if (openings & NORTH) == 0:
				_add_horizontal_wall(cell_to_world_center(cell) + Vector2(0.0, -_cell_size * 0.5))
			if (openings & WEST) == 0:
				_add_vertical_wall(cell_to_world_center(cell) + Vector2(-_cell_size * 0.5, 0.0))
			if cell_y == int(_maze_data["height"]) - 1:
				_add_horizontal_wall(cell_to_world_center(cell) + Vector2(0.0, _cell_size * 0.5))
			if cell_x == int(_maze_data["width"]) - 1:
				_add_vertical_wall(cell_to_world_center(cell) + Vector2(_cell_size * 0.5, 0.0))


func _add_horizontal_wall(wall_position: Vector2) -> void:
	# Un léger chevauchement ferme proprement les angles à grande vitesse.
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(_cell_size + wall_thickness, wall_thickness)
	_add_collision_shape(wall_position, wall_shape)


func _add_vertical_wall(wall_position: Vector2) -> void:
	# Les murs verticaux utilisent la même épaisseur que les murs horizontaux.
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(wall_thickness, _cell_size + wall_thickness)
	_add_collision_shape(wall_position, wall_shape)


func _add_collision_shape(wall_position: Vector2, wall_shape: Shape2D) -> void:
	var collision_shape := CollisionShape2D.new()
	collision_shape.position = wall_position
	collision_shape.shape = wall_shape
	wall_body.add_child(collision_shape)


func _draw() -> void:
	if _maze_data.is_empty():
		return

	# Le parchemin sombre et ses cases alternées gardent une ambiance médiévale lisible.
	draw_rect(_maze_rect.grow(18.0), Color("24182e"), true)
	draw_rect(_maze_rect, Color("4a3452"), true)
	for cell_y in int(_maze_data["height"]):
		for cell_x in int(_maze_data["width"]):
			var cell := Vector2i(cell_x, cell_y)
			if (cell_x + cell_y) % 2 == 0:
				draw_rect(
					Rect2(_maze_origin + Vector2(cell) * _cell_size, Vector2.ONE * _cell_size),
					Color("513b59"),
					true,
				)

	# Les murs de pierre sont dessinés au-dessus du sol avec un fin reflet.
	_draw_all_walls(Color("17111d"), wall_thickness + 5.0)
	_draw_all_walls(Color("aa8b73"), wall_thickness)
	_draw_all_walls(Color("d6b98e"), 2.0)

	# Deux runes distinctes rendent immédiatement lisibles le départ et la sortie.
	var start_position := cell_to_world_center(_maze_data["start_cell"])
	var exit_position := cell_to_world_center(_maze_data["exit_cell"])
	draw_circle(start_position, _cell_size * 0.22, Color("5f9d8a"), false, 4.0, true)
	draw_circle(exit_position, _cell_size * 0.28, Color("ffd66b", 0.22), true)
	draw_circle(exit_position, _cell_size * 0.24, Color("ffd66b"), false, 5.0, true)
	draw_line(exit_position + Vector2(0.0, -_cell_size * 0.2), exit_position + Vector2(0.0, _cell_size * 0.2), Color("fff1b8"), 3.0, true)
	draw_line(exit_position + Vector2(-_cell_size * 0.16, 0.0), exit_position + Vector2(_cell_size * 0.16, 0.0), Color("fff1b8"), 3.0, true)


func _draw_all_walls(wall_color: Color, line_width: float) -> void:
	# Le même parcours sert aux trois couches visuelles sans dupliquer de géométrie.
	for cell_y in int(_maze_data["height"]):
		for cell_x in int(_maze_data["width"]):
			var cell := Vector2i(cell_x, cell_y)
			var cell_top_left := _maze_origin + Vector2(cell) * _cell_size
			var cell_bottom_right := cell_top_left + Vector2.ONE * _cell_size
			var openings: int = _maze_data["openings"][cell]
			if (openings & NORTH) == 0:
				draw_line(cell_top_left, Vector2(cell_bottom_right.x, cell_top_left.y), wall_color, line_width, true)
			if (openings & WEST) == 0:
				draw_line(cell_top_left, Vector2(cell_top_left.x, cell_bottom_right.y), wall_color, line_width, true)
			if cell_y == int(_maze_data["height"]) - 1:
				draw_line(Vector2(cell_top_left.x, cell_bottom_right.y), cell_bottom_right, wall_color, line_width, true)
			if cell_x == int(_maze_data["width"]) - 1:
				draw_line(Vector2(cell_bottom_right.x, cell_top_left.y), cell_bottom_right, wall_color, line_width, true)
