extends Control

# Références vers les éléments d'interface propres à chaque profil.
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
	# Le lobby écoute les changements globaux et autorise les nouvelles inscriptions.
	PlayerRegistry.players_changed.connect(_refresh)
	PlayerRegistry.set_joining_enabled(true)
	_refresh(PlayerRegistry.get_players())


func _exit_tree() -> void:
	# Hors du lobby, une commande ne doit plus inscrire un nouveau joueur.
	PlayerRegistry.set_joining_enabled(false)
	if PlayerRegistry.players_changed.is_connected(_refresh):
		PlayerRegistry.players_changed.disconnect(_refresh)


func _refresh(players: Array[LocalPlayer]) -> void:
	# Actualise d'abord le compteur commun aux trois cartes.
	player_count.text = "%d / %d joueurs connectés" % [
		players.size(),
		PlayerRegistry.PROFILE_ORDER.size(),
	]

	# Chaque carte reflète la présence du joueur associé à son profil.
	for profile_id in PlayerRegistry.PROFILE_ORDER:
		var status: Label = status_labels[profile_id]
		var card: PanelContainer = cards[profile_id]
		var player := PlayerRegistry.get_player_for_profile(profile_id)
		if player == null:
			status.text = "En attente…"
			status.modulate = Color("a9b1c6")
			card.modulate = Color(1, 1, 1, 0.68)
		else:
			status.text = "%s — prêt !" % player.display_name
			status.modulate = player.color
			card.modulate = Color.WHITE
