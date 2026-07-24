extends Node

# Identifiants du protocole partagé avec PlayerRegistry.
const KEYBOARD_LEFT := &"keyboard_left"
const KEYBOARD_RIGHT := &"keyboard_right"
const MOUSE := &"mouse"

# Positions physiques choisies pour un clavier français AZERTY.
# Elles restent identiques même lorsque Maj modifie le caractère produit.
const LEFT_ACTION_2_KEY: Key = KEY_LESS
const RIGHT_ACTION_1_KEY: Key = KEY_PERIOD
const RIGHT_ACTION_2_KEY: Key = KEY_SLASH

# Réglages communs du contrôle par zones de la souris.
const MOUSE_EDGE_ZONE_RATIO := 0.22
const DEFAULT_VIEWPORT_SIZE := Vector2(1152.0, 648.0)

var joining_enabled := false
var _registry: Node
# La touche ISO < > peut produire un physical_keycode différent selon le pilote Windows.
var _left_action_2_physical_key: Key = KEY_NONE
var _directions := {
	KEYBOARD_LEFT: {"left": false, "right": false, "up": false, "down": false},
	KEYBOARD_RIGHT: {"left": false, "right": false, "up": false, "down": false},
}


func _ready() -> void:
	# En production, le registre est l'Autoload créé juste avant ce routeur.
	if _registry == null:
		_registry = get_node_or_null("/root/PlayerRegistry")
	if _registry == null:
		push_error("PlayerInputRouter ne trouve pas l'Autoload PlayerRegistry.")
		return

	_registry.players_changed.connect(_on_players_changed)
	# Les impulsions sont effacées après les _physics_process des éléments de jeu.
	process_physics_priority = 1000


func _exit_tree() -> void:
	if _registry != null and _registry.players_changed.is_connected(_on_players_changed):
		_registry.players_changed.disconnect(_on_players_changed)


func _physics_process(_delta: float) -> void:
	if _registry == null:
		return
	# La position absolue permet à la souris de continuer sans mouvement permanent.
	_refresh_mouse_direction()
	# Les commandes « just_pressed » ne doivent durer qu'un tick physique.
	for player in _registry.get_players():
		player.input._finish_physics_frame()


func _input(event: InputEvent) -> void:
	if _registry == null:
		return

	# Échap réinitialise la session uniquement lorsque le lobby accepte les inscriptions.
	if joining_enabled and event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_registry.clear_players()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return

	# Un événement de participation peut créer un joueur avant d'être routé vers lui.
	if joining_enabled:
		var joining_profile := _get_joining_profile(event)
		if joining_profile != &"":
			_registry.join_profile(joining_profile)

	# Traduit ensuite l'événement brut selon son type de périphérique.
	if event is InputEventKey:
		_route_key(event)
	elif event is InputEventMouseMotion:
		_route_mouse_motion(event)
	elif event is InputEventMouseButton:
		_route_mouse_button(event)


## Injecte un registre différent, principalement pour les tests automatisés.
func set_registry(registry: Node) -> void:
	_registry = registry


## Active ou désactive l'inscription, sans couper les commandes des joueurs existants.
func set_joining_enabled(enabled: bool) -> void:
	joining_enabled = enabled


# Détermine quel profil souhaite rejoindre, sans interpréter son action de gameplay.
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
	var left_player: LocalPlayer = _registry.get_player_for_profile(KEYBOARD_LEFT)
	var right_player: LocalPlayer = _registry.get_player_for_profile(KEYBOARD_RIGHT)
	
	# Les directions sont actualisées à l'appui comme au relâchement.
	if event.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_set_direction_key(KEYBOARD_LEFT, event.physical_keycode, event.pressed)
		match event.physical_keycode :
			KEY_W :left_player.input._set_action_up(event.pressed)
			KEY_A :left_player.input._set_action_left(event.pressed)
			KEY_S :left_player.input._set_action_down(event.pressed)
			KEY_D :left_player.input._set_action_right(event.pressed)
	elif event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		_set_direction_key(KEYBOARD_RIGHT, event.keycode, event.pressed)
		match event.physical_keycode :
			KEY_UP :right_player.input._set_action_up(event.pressed)
			KEY_LEFT :right_player.input._set_action_left(event.pressed)
			KEY_DOWN :right_player.input._set_action_down(event.pressed)
			KEY_RIGHT :right_player.input._set_action_right(event.pressed)

	# Le clavier gauche expose simplement Action 1 et Action 2.
	if left_player != null:
		if event.keycode == KEY_SHIFT and event.location != KEY_LOCATION_RIGHT:
			left_player.input._set_action_1_pressed(event.pressed)
		elif event.pressed and not event.echo and _is_left_action_2_event(event):
			# Mémorise le code réellement reçu pour rendre le relâchement fiable.
			_left_action_2_physical_key = event.physical_keycode
			left_player.input._set_action_2_pressed(true)
		elif not event.pressed and (
			(
				_left_action_2_physical_key != KEY_NONE
				and event.physical_keycode == _left_action_2_physical_key
			)
			or _is_left_action_2_event(event)
		):
			_left_action_2_physical_key = KEY_NONE
			left_player.input._set_action_2_pressed(false)

	# Les positions physiques rendent les deux actions indépendantes de Maj.
	if right_player != null:
		if event.physical_keycode == RIGHT_ACTION_1_KEY:
			right_player.input._set_action_1_pressed(event.pressed)
		elif event.physical_keycode == RIGHT_ACTION_2_KEY:
			right_player.input._set_action_2_pressed(event.pressed)


# Reconnaît la touche ISO < > malgré les variations entre dispositions et pilotes.
func _is_left_action_2_event(event: InputEventKey) -> bool:
	return (
		event.physical_keycode == LEFT_ACTION_2_KEY
		or event.keycode == KEY_LESS
		or event.key_label == KEY_LESS
		or event.unicode == "<".unicode_at(0)
		or event.unicode == ">".unicode_at(0)
	)


# Convertit une touche directionnelle en l'un des quatre états du profil.
func _set_direction_key(profile_id: StringName, keycode: Key, pressed: bool) -> void:
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

	if direction_name == &"":
		return
	_directions[profile_id][direction_name] = pressed
	_update_keyboard_direction(profile_id)


# Reconstruit le vecteur à partir des quatre touches actuellement maintenues.
func _update_keyboard_direction(profile_id: StringName) -> void:
	var player: LocalPlayer = _registry.get_player_for_profile(profile_id)
	if player == null:
		return
	var state: Dictionary = _directions[profile_id]
	var direction := Vector2(
		(1.0 if state["right"] else 0.0) - (1.0 if state["left"] else 0.0),
		(1.0 if state["down"] else 0.0) - (1.0 if state["up"] else 0.0),
	)
	player.input._set_direction(direction)


# Traduit immédiatement une nouvelle position de souris en direction normalisée.
func _route_mouse_motion(event: InputEventMouseMotion) -> void:
	var player: LocalPlayer = _registry.get_player_for_profile(MOUSE)
	if player == null:
		return
	player.input._set_direction(
		_get_mouse_direction(event.position, _get_input_viewport_size())
	)


# Les clics exposent les mêmes Action 1 et Action 2 que les claviers.
func _route_mouse_button(event: InputEventMouseButton) -> void:
	var player: LocalPlayer = _registry.get_player_for_profile(MOUSE)
	if player == null:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		player.input._set_action_1_pressed(event.pressed)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		player.input._set_action_2_pressed(event.pressed)
	player.input._set_direction(
		_get_mouse_direction(event.position, _get_input_viewport_size())
	)


# Utilise la vraie fenêtre en jeu et une taille connue dans le test autonome.
func _get_input_viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size
	return DEFAULT_VIEWPORT_SIZE


# Transforme une position absolue en vecteur ; le centre constitue une zone morte.
func _get_mouse_direction(mouse_position: Vector2, viewport_size: Vector2) -> Vector2:
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


# Réévalue la souris à chaque tick, même sans événement de mouvement.
func _refresh_mouse_direction() -> void:
	var player: LocalPlayer = _registry.get_player_for_profile(MOUSE)
	var viewport := get_viewport()
	if player == null or viewport == null:
		return
	player.input._set_direction(
		_get_mouse_direction(viewport.get_mouse_position(), viewport.get_visible_rect().size)
	)


# Une déconnexion efface les touches maintenues par le profil libéré.
func _on_players_changed(_players: Array[LocalPlayer]) -> void:
	if _registry.get_player_for_profile(KEYBOARD_LEFT) == null:
		_left_action_2_physical_key = KEY_NONE
	for profile_id in _directions:
		if _registry.get_player_for_profile(profile_id) == null:
			_directions[profile_id] = {
				"left": false,
				"right": false,
				"up": false,
				"down": false,
			}
