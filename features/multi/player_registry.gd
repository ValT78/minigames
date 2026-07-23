extends Node

## Émis après toute connexion, déconnexion ou réinitialisation des joueurs.
signal players_changed(players: Array[LocalPlayer])

# Identifiants stables des profils physiques disponibles.
const KEYBOARD_LEFT := &"keyboard_left"
const KEYBOARD_RIGHT := &"keyboard_right"
const MOUSE := &"mouse"

# Ordre commun utilisé par le lobby et les scènes qui répartissent les profils.
const PROFILE_ORDER: Array[StringName] = [
	KEYBOARD_LEFT,
	KEYBOARD_RIGHT,
	MOUSE,
]

# Métadonnées fixes d'un profil. Elles ne décrivent aucune action de gameplay.
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
		"controls": "Position  •  Clic gauche  •  Clic droit",
		"color": Color("ff729f"),
	},
}

# État global conservé par cet Autoload pendant toute la session.
var _players: Array[LocalPlayer] = []
var _next_player_id := 1


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
## Les LocalPlayer restent les mêmes objets afin que leur état d'entrée reste à jour.
func get_players() -> Array[LocalPlayer]:
	return _players.duplicate()


## Déconnecte tous les joueurs et remet la numérotation à son état initial.
func clear_players() -> void:
	if _players.is_empty():
		return
	_players.clear()
	_next_player_id = 1
	players_changed.emit(get_players())
