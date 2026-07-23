extends Control

@onready var player_count: Label = %PlayerCount
@onready var status_labels := {
	PlayerRegistry.KEYBOARD_LEFT: %LeftStatus,
	PlayerRegistry.KEYBOARD_RIGHT: %RightStatus,
	PlayerRegistry.MOUSE: %MouseStatus,
}
@onready var cards := {
	PlayerRegistry.KEYBOARD_LEFT: %LeftCard,
	PlayerRegistry.KEYBOARD_RIGHT: %RightCard,
	PlayerRegistry.MOUSE: %MouseCard,
}


func _ready() -> void:
	PlayerRegistry.players_changed.connect(_refresh)
	_refresh(PlayerRegistry.get_players())


func _exit_tree() -> void:
	if PlayerRegistry.players_changed.is_connected(_refresh):
		PlayerRegistry.players_changed.disconnect(_refresh)


func _input(event: InputEvent) -> void:
	# Si c'est un input de clavier clavier
	if event is InputEventKey and event.pressed and not event.echo:
		# Clear player with escape
		if event.keycode == KEY_ESCAPE:
			PlayerRegistry.clear_players()
			get_viewport().set_input_as_handled()
			return

		# Identifier un profil de touche, et ajouter le joueur
		var profile_id := _profile_for_key(event)
		if profile_id != &"" and PlayerRegistry.join_profile(profile_id):
			get_viewport().set_input_as_handled()
	
	#Si c'est un input de souris
	elif event is InputEventMouseButton and event.pressed:
		if PlayerRegistry.join_profile(PlayerRegistry.MOUSE):
			get_viewport().set_input_as_handled()

# quelle touche = quel profil
func _profile_for_key(event: InputEventKey) -> StringName:
	var left_keys := [KEY_W, KEY_A, KEY_S, KEY_D]
	if event.physical_keycode in left_keys:
		return PlayerRegistry.KEYBOARD_LEFT

	var right_keys := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
	if event.keycode in right_keys:
		return PlayerRegistry.KEYBOARD_RIGHT

	return &""


func _refresh(players: Array[Dictionary]) -> void:
	player_count.text = "%d / %d joueurs connectés" % [
		players.size(),
		PlayerRegistry.PROFILE_ORDER.size(),
	]

	for profile_id in PlayerRegistry.PROFILE_ORDER:
		var status: Label = status_labels[profile_id]
		var card: PanelContainer = cards[profile_id]
		var player := PlayerRegistry.get_player_for_profile(profile_id)
		if player.is_empty():
			status.text = "En attente…"
			status.modulate = Color("a9b1c6")
			card.modulate = Color(1, 1, 1, 0.68)
		else:
			status.text = "%s a rejoint !" % player["name"]
			status.modulate = player["color"]
			card.modulate = Color.WHITE
