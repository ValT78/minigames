extends Node

## Émis après toute connexion, déconnexion ou réinitialisation des joueurs.
signal players_changed(players: Array[LocalPlayer])

# Identifiants stables utilisés partout à la place des touches physiques.
const KEYBOARD_LEFT := &"keyboard_left"
const KEYBOARD_RIGHT := &"keyboard_right"
const MOUSE := &"mouse"

# Positions physiques choisies pour un clavier français AZERTY.
# Elles restent identiques même lorsque Maj modifie le caractère produit.
const LEFT_DASH_KEY: Key = KEY_LESS
const RIGHT_JUMP_KEY: Key = KEY_PERIOD
const RIGHT_DASH_KEY: Key = KEY_SLASH

# Réglages communs du contrôle par zones de la souris.
const MOUSE_EDGE_ZONE_RATIO := 0.22
const DEFAULT_VIEWPORT_SIZE := Vector2(1152.0, 648.0)

# Ordre d'affichage et de placement des trois profils disponibles.
const PROFILE_ORDER: Array[StringName] = [
	KEYBOARD_LEFT,
	KEYBOARD_RIGHT,
	MOUSE,
]

# Métadonnées fixes utilisées pour construire et présenter un joueur.
const PROFILES := {
	KEYBOARD_LEFT: {
		"name": "Clavier gauche",
		"controls": "ZQSD  •  Maj gauche  •  <",
		"color": Color("5cc8ff"),
	},
	KEYBOARD_RIGHT: {
		"name": "Clavier droit",
		"controls": "Flèches  •  /  •  !",
		"color": Color("ffcf5c"),
	},
	MOUSE: {
		"name": "Souris",
		"controls": "Mouvement  •  Clic gauche  •  Clic droit",
		"color": Color("ff729f"),
	},
}

# État global conservé par cet Autoload pendant toute la session.
var joining_enabled := false
var _players: Array[LocalPlayer] = []
var _next_player_id := 1
# États physiques nécessaires pour reconstruire un vecteur continu au clavier.
var _directions := {
	KEYBOARD_LEFT: {"left": false, "right": false, "up": false, "down": false},
	KEYBOARD_RIGHT: {"left": false, "right": false, "up": false, "down": false},
}


func _ready() -> void:
	# Les impulsions sont effacées après les _physics_process des éléments de jeu.
	process_physics_priority = 1000


func _physics_process(_delta: float) -> void:
	# La position absolue permet à la souris de continuer sans mouvement permanent.
	_refresh_mouse_movement()
	# Les commandes « just_pressed » ne doivent durer qu'un tick physique.
	for player in _players:
		player.input._finish_physics_frame()


func _input(event: InputEvent) -> void:
	# Échap réinitialise la session uniquement lorsque le lobby accepte les inscriptions.
	if joining_enabled and event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			clear_players()
			get_viewport().set_input_as_handled()
			return

	# Un événement de participation peut créer un joueur avant d'être routé vers lui.
	if joining_enabled:
		var joining_profile := _get_joining_profile(event)
		if joining_profile != &"":
			join_profile(joining_profile)

	# La suite traduit l'événement brut selon son type de périphérique.
	if event is InputEventKey:
		_route_key(event)
	elif event is InputEventMouseMotion:
		_route_mouse_motion(event)
	elif event is InputEventMouseButton:
		_route_mouse_button(event)


## Active ou désactive l'inscription de nouveaux joueurs, sans couper leurs commandes.
func set_joining_enabled(enabled: bool) -> void:
	joining_enabled = enabled


## Ajoute le profil s'il existe et n'est pas déjà utilisé.
## Renvoie vrai uniquement lorsqu'un nouveau joueur a réellement été créé.
func join_profile(profile_id: StringName) -> bool:
	if not PROFILES.has(profile_id) or has_profile(profile_id):
		return false

	# Les identifiants ne sont jamais recyclés avant une réinitialisation complète.
	var player_number := _next_player_id
	_next_player_id += 1
	var profile: Dictionary = PROFILES[profile_id]
	_players.append(LocalPlayer.new(
		player_number,
		"Joueur %d" % player_number,
		profile_id,
		profile["name"],
		profile["color"],
	))
	players_changed.emit(get_players())
	return true


## Retire le joueur utilisant ce profil et prévient les scènes abonnées.
func leave_profile(profile_id: StringName) -> bool:
	for index in _players.size():
		if _players[index].profile_id == profile_id:
			_players.remove_at(index)
			_reset_profile_input(profile_id)
			players_changed.emit(get_players())
			return true
	return false


## Indique si le profil appartient déjà à un joueur connecté.
func has_profile(profile_id: StringName) -> bool:
	return get_player_for_profile(profile_id) != null


## Retrouve le joueur d'un profil, ou null si personne ne l'utilise.
func get_player_for_profile(profile_id: StringName) -> LocalPlayer:
	for player in _players:
		if player.profile_id == profile_id:
			return player
	return null


## Renvoie une copie de la liste pour empêcher une scène de modifier le registre.
## Les LocalPlayer restent les mêmes objets afin que leurs inputs restent à jour.
func get_players() -> Array[LocalPlayer]:
	return _players.duplicate()


## Déconnecte tous les joueurs et remet la numérotation à son état initial.
func clear_players() -> void:
	if _players.is_empty():
		return
	_players.clear()
	_next_player_id = 1
	_reset_profile_input(KEYBOARD_LEFT)
	_reset_profile_input(KEYBOARD_RIGHT)
	players_changed.emit(get_players())


# Détermine quel profil souhaite rejoindre, sans encore interpréter son action.
func _get_joining_profile(event: InputEvent) -> StringName:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
			return KEYBOARD_LEFT
		if event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			return KEYBOARD_RIGHT
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return MOUSE
	return &""


func _route_key(event: InputEventKey) -> void:
	# Les directions mettent à jour un état maintenu à l'appui comme au relâchement.
	if event.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_set_direction(KEYBOARD_LEFT, event.physical_keycode, event.pressed)
	elif event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		_set_direction(KEYBOARD_RIGHT, event.keycode, event.pressed)

	# Le clavier gauche utilise Maj gauche pour éviter le conflit avec Maj droite.
	var left_player := get_player_for_profile(KEYBOARD_LEFT)
	if left_player != null:
		if event.keycode == KEY_SHIFT and event.location != KEY_LOCATION_RIGHT:
			left_player.input._set_jump_pressed(event.pressed)
		elif event.pressed and not event.echo and event.physical_keycode == LEFT_DASH_KEY:
			left_player.input._press_dash()

	# Les deux touches droites sont reconnues par leur position, jamais par leur caractère.
	var right_player := get_player_for_profile(KEYBOARD_RIGHT)
	if right_player != null:
		if event.physical_keycode == RIGHT_JUMP_KEY:
			right_player.input._set_jump_pressed(event.pressed)
		elif event.pressed and not event.echo and event.physical_keycode == RIGHT_DASH_KEY:
			right_player.input._press_dash()


# Convertit une touche directionnelle en l'un des quatre états du profil.
func _set_direction(profile_id: StringName, keycode: Key, pressed: bool) -> void:
	var direction_name := &""
	if profile_id == KEYBOARD_LEFT:
		direction_name = {
			KEY_A: &"left",
			KEY_D: &"right",
			KEY_W: &"up",
			KEY_S: &"down",
		}.get(keycode, &"")
	else:
		direction_name = {
			KEY_LEFT: &"left",
			KEY_RIGHT: &"right",
			KEY_UP: &"up",
			KEY_DOWN: &"down",
		}.get(keycode, &"")

	# Une touche inconnue ne doit jamais altérer les directions mémorisées.
	if direction_name == &"":
		return
	_directions[profile_id][direction_name] = pressed
	_update_keyboard_movement(profile_id)


# Reconstruit le vecteur à partir des quatre touches actuellement maintenues.
func _update_keyboard_movement(profile_id: StringName) -> void:
	var player := get_player_for_profile(profile_id)
	if player == null:
		return
	var state: Dictionary = _directions[profile_id]
	var movement := Vector2(
		(1.0 if state["right"] else 0.0) - (1.0 if state["left"] else 0.0),
		(1.0 if state["down"] else 0.0) - (1.0 if state["up"] else 0.0),
	)
	player.input._set_movement(movement)


# Traduit immédiatement une nouvelle position de souris en commande normalisée.
func _route_mouse_motion(event: InputEventMouseMotion) -> void:
	var player := get_player_for_profile(MOUSE)
	if player == null:
		return
	player.input._set_movement(
		_get_mouse_movement(event.position, _get_input_viewport_size())
	)


# Les clics exposent le même saut et le même dash que les deux claviers.
func _route_mouse_button(event: InputEventMouseButton) -> void:
	var player := get_player_for_profile(MOUSE)
	if player == null:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		player.input._set_jump_pressed(event.pressed)
	elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		player.input._press_dash()
	player.input._set_movement(
		_get_mouse_movement(event.position, _get_input_viewport_size())
	)


# Utilise la vraie fenêtre en jeu et une taille connue dans le test autonome.
func _get_input_viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size
	return DEFAULT_VIEWPORT_SIZE


# Transforme une position absolue en vecteur ; le centre constitue une zone morte.
func _get_mouse_movement(mouse_position: Vector2, viewport_size: Vector2) -> Vector2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	# Une souris hors de la fenêtre ne doit pas laisser le joueur avancer seul.
	if (
		mouse_position.x < 0.0
		or mouse_position.y < 0.0
		or mouse_position.x > viewport_size.x
		or mouse_position.y > viewport_size.y
	):
		return Vector2.ZERO
	# X et Y sont calculés séparément afin que les coins activent deux directions.
	var horizontal := _get_mouse_axis(mouse_position.x, viewport_size.x)
	var vertical := _get_mouse_axis(mouse_position.y, viewport_size.y)
	return Vector2(horizontal, vertical).limit_length(1.0)


# Calcule progressivement une direction entre la zone centrale et un bord.
func _get_mouse_axis(position: float, size: float) -> float:
	var edge_size := size * MOUSE_EDGE_ZONE_RATIO
	if position < edge_size:
		return -clampf((edge_size - position) / edge_size, 0.0, 1.0)
	if position > size - edge_size:
		return clampf((position - (size - edge_size)) / edge_size, 0.0, 1.0)
	return 0.0


# Réévalue la souris à chaque tick, même lorsqu'aucun événement de mouvement n'arrive.
func _refresh_mouse_movement() -> void:
	var player := get_player_for_profile(MOUSE)
	var viewport := get_viewport()
	if player == null or viewport == null:
		return
	player.input._set_movement(
		_get_mouse_movement(viewport.get_mouse_position(), viewport.get_visible_rect().size)
	)


# Efface les touches conservées lors du départ d'un profil clavier.
func _reset_profile_input(profile_id: StringName) -> void:
	if _directions.has(profile_id):
		_directions[profile_id] = {
			"left": false,
			"right": false,
			"up": false,
			"down": false,
		}
