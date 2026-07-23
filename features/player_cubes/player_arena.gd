extends Node2D

# Scène réutilisable instanciée une fois pour chaque joueur connecté.
const PLAYER_CUBE_SCENE := preload("res://features/player_cubes/player_cube.tscn")

# Références vers le sol physique, son visuel et le conteneur des cubes.
@onready var floor_body: StaticBody2D = %FloorBody
@onready var floor_shape: CollisionShape2D = %FloorShape
@onready var floor_visual: Polygon2D = %FloorVisual
@onready var floor_line: Line2D = %FloorLine
@onready var cubes: Node2D = %Cubes

# Associe chaque identifiant de joueur au cube déjà présent dans l'arène.
var _player_cubes: Dictionary[int, PlayerCube] = {}
var _floor_y := 0.0


func _ready() -> void:
	# L'arène est autonome : elle observe directement le registre global.
	PlayerRegistry.players_changed.connect(_sync_player_cubes)
	get_viewport().size_changed.connect(_layout_world)
	_layout_world()
	_sync_player_cubes(PlayerRegistry.get_players())


func _exit_tree() -> void:
	# Nettoie les connexions lorsque cette scène enfant est retirée.
	if PlayerRegistry.players_changed.is_connected(_sync_player_cubes):
		PlayerRegistry.players_changed.disconnect(_sync_player_cubes)
	if get_viewport().size_changed.is_connected(_layout_world):
		get_viewport().size_changed.disconnect(_layout_world)


func _sync_player_cubes(players: Array[LocalPlayer]) -> void:
	# Crée les cubes manquants sans toucher à ceux qui existent déjà.
	var active_ids: Array[int] = []
	for player in players:
		active_ids.append(player.id)
		if not _player_cubes.has(player.id):
			var cube: PlayerCube = PLAYER_CUBE_SCENE.instantiate()
			_player_cubes[player.id] = cube
			cubes.add_child(cube)
			cube.setup(player, _get_spawn_position(player.profile_id))

	# Supprime ensuite les cubes dont le joueur n'est plus dans le registre.
	for player_id in _player_cubes.keys():
		if player_id not in active_ids:
			_player_cubes[player_id].queue_free()
			_player_cubes.erase(player_id)


func _layout_world() -> void:
	# Adapte le sol aux dimensions courantes de la fenêtre.
	var viewport_size := get_viewport_rect().size
	_floor_y = viewport_size.y - 54.0
	floor_body.position = Vector2(viewport_size.x * 0.5, _floor_y + 30.0)
	var rectangle: RectangleShape2D = floor_shape.shape
	rectangle.size = Vector2(viewport_size.x, 60.0)
	floor_visual.polygon = PackedVector2Array([
		Vector2(-viewport_size.x * 0.5, -30.0),
		Vector2(viewport_size.x * 0.5, -30.0),
		Vector2(viewport_size.x * 0.5, 30.0),
		Vector2(-viewport_size.x * 0.5, 30.0),
	])
	floor_line.points = PackedVector2Array([
		Vector2(-viewport_size.x * 0.5, -30.0),
		Vector2(viewport_size.x * 0.5, -30.0),
	])

	# Replace uniquement les cubes qui se retrouveraient sous le nouveau sol.
	for player_id in _player_cubes:
		var cube := _player_cubes[player_id]
		cube.position.y = minf(cube.position.y, _floor_y - 24.0)


# Répartit les profils à gauche, au centre et à droite de l'arène.
func _get_spawn_position(profile_id: StringName) -> Vector2:
	var profile_index := PlayerRegistry.PROFILE_ORDER.find(profile_id)
	var viewport_width := get_viewport_rect().size.x
	return Vector2(
		viewport_width * float(profile_index + 1) / 4.0,
		_floor_y - 80.0,
	)
