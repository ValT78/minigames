class_name WizardMazeGenerator
extends RefCounted

# Chaque bit indique qu'un passage est ouvert depuis une cellule.
const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

var _random_number_generator := RandomNumberGenerator.new()


func generate(width: int, height: int, target_path_length: int) -> Dictionary:
	# Une graine différente produit un nouveau plan à chaque manche.
	_random_number_generator.randomize()
	var start_cell := Vector2i(0, height / 2)
	var openings := _create_closed_grid(width, height)
	_carve_dense_maze(openings, width, height, start_cell)

	# La sortie choisie donne une course assez longue sans devenir impossible en 15 secondes.
	var distances := _calculate_distances(openings, start_cell)
	var exit_cell := _select_border_exit(distances, width, height, start_cell, target_path_length)
	return {
		"width": width,
		"height": height,
		"openings": openings,
		"start_cell": start_cell,
		"exit_cell": exit_cell,
		"exit_distance": distances.get(exit_cell, 0),
	}


func _create_closed_grid(width: int, height: int) -> Dictionary:
	# Toutes les cellules existent dès le départ et sont séparées par quatre murs.
	var openings := {}
	for cell_y in height:
		for cell_x in width:
			openings[Vector2i(cell_x, cell_y)] = 0
	return openings


func _carve_dense_maze(
	openings: Dictionary,
	width: int,
	height: int,
	start_cell: Vector2i,
) -> void:
	# Le parcours en profondeur garantit un labyrinthe parfait et toujours résoluble.
	var visited := {start_cell: true}
	var cell_stack: Array[Vector2i] = [start_cell]
	var arrival_directions := {start_cell: Vector2i.ZERO}
	var straight_run_lengths := {start_cell: 0}

	while not cell_stack.is_empty():
		var current_cell: Vector2i = cell_stack.back()
		var candidates := _get_unvisited_neighbors(current_cell, visited, width, height)
		if candidates.is_empty():
			cell_stack.pop_back()
			continue

		# Les virages sont fortement favorisés et une ligne droite dépasse rarement deux cases.
		var arrival_direction: Vector2i = arrival_directions[current_cell]
		var straight_run_length: int = straight_run_lengths[current_cell]
		var selected_candidate := _pick_turning_candidate(
			candidates,
			arrival_direction,
			straight_run_length,
		)
		var next_cell: Vector2i = selected_candidate["cell"]
		var selected_direction: Vector2i = selected_candidate["direction"]
		_open_passage(openings, current_cell, next_cell, selected_direction)

		visited[next_cell] = true
		arrival_directions[next_cell] = selected_direction
		straight_run_lengths[next_cell] = (
			straight_run_length + 1 if selected_direction == arrival_direction else 1
		)
		cell_stack.append(next_cell)


func _get_unvisited_neighbors(
	cell: Vector2i,
	visited: Dictionary,
	width: int,
	height: int,
) -> Array[Dictionary]:
	# Seuls les voisins intérieurs encore fermés peuvent prolonger le parcours.
	var neighbors: Array[Dictionary] = []
	for direction in CARDINAL_DIRECTIONS:
		var neighbor_cell := cell + direction
		if not _is_inside(neighbor_cell, width, height) or visited.has(neighbor_cell):
			continue
		neighbors.append({"cell": neighbor_cell, "direction": direction})
	return neighbors


func _pick_turning_candidate(
	candidates: Array[Dictionary],
	arrival_direction: Vector2i,
	straight_run_length: int,
) -> Dictionary:
	# Dupliquer les candidats perpendiculaires suffit à obtenir un biais simple et lisible.
	var weighted_candidates: Array[Dictionary] = []
	for candidate in candidates:
		var direction: Vector2i = candidate["direction"]
		var is_straight := direction == arrival_direction
		if is_straight and straight_run_length >= 2 and candidates.size() > 1:
			continue
		var candidate_weight := 1 if is_straight else 5
		for _weight_index in candidate_weight:
			weighted_candidates.append(candidate)

	# Un unique prolongement reste autorisé pour que toutes les cellules soient visitées.
	if weighted_candidates.is_empty():
		weighted_candidates = candidates
	return weighted_candidates[_random_number_generator.randi_range(0, weighted_candidates.size() - 1)]


func _open_passage(
	openings: Dictionary,
	from_cell: Vector2i,
	to_cell: Vector2i,
	direction: Vector2i,
) -> void:
	# Les deux cellules mémorisent la même ouverture dans des sens opposés.
	openings[from_cell] |= _direction_to_bit(direction)
	openings[to_cell] |= _direction_to_bit(-direction)


func _calculate_distances(openings: Dictionary, start_cell: Vector2i) -> Dictionary:
	# Une recherche en largeur mesure le vrai chemin dans le labyrinthe.
	var distances := {start_cell: 0}
	var cells_to_visit: Array[Vector2i] = [start_cell]
	var next_cell_index := 0
	while next_cell_index < cells_to_visit.size():
		var current_cell := cells_to_visit[next_cell_index]
		next_cell_index += 1
		for direction in CARDINAL_DIRECTIONS:
			if not _has_opening(openings, current_cell, direction):
				continue
			var neighbor_cell := current_cell + direction
			if distances.has(neighbor_cell):
				continue
			distances[neighbor_cell] = distances[current_cell] + 1
			cells_to_visit.append(neighbor_cell)
	return distances


func _select_border_exit(
	distances: Dictionary,
	width: int,
	height: int,
	start_cell: Vector2i,
	target_path_length: int,
) -> Vector2i:
	# Une cellule de bord proche de la longueur cible rend la sortie évidente et équilibrée.
	var selected_cell := start_cell
	var smallest_distance_difference := 1_000_000
	for cell: Vector2i in distances:
		if cell == start_cell or not _is_border_cell(cell, width, height):
			continue
		var path_length: int = distances[cell]
		var distance_difference := absi(path_length - target_path_length)
		if distance_difference < smallest_distance_difference:
			smallest_distance_difference = distance_difference
			selected_cell = cell
	return selected_cell


func _has_opening(openings: Dictionary, cell: Vector2i, direction: Vector2i) -> bool:
	return (int(openings[cell]) & _direction_to_bit(direction)) != 0


func _direction_to_bit(direction: Vector2i) -> int:
	match direction:
		Vector2i.UP:
			return NORTH
		Vector2i.RIGHT:
			return EAST
		Vector2i.DOWN:
			return SOUTH
		Vector2i.LEFT:
			return WEST
	return 0


func _is_inside(cell: Vector2i, width: int, height: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func _is_border_cell(cell: Vector2i, width: int, height: int) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == width - 1 or cell.y == height - 1
