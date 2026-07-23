extends Node

signal players_changed(players: Array[Dictionary])

const KEYBOARD_LEFT := &"keyboard_left"
const KEYBOARD_RIGHT := &"keyboard_right"
const MOUSE := &"mouse"

const PROFILE_ORDER: Array[StringName] = [
	KEYBOARD_LEFT,
	KEYBOARD_RIGHT,
	MOUSE,
]

const PROFILES := {
	KEYBOARD_LEFT: {
		"name": "Clavier gauche",
		"controls": "ZQSD  •  Maj  •  <",
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

var _players: Array[Dictionary] = []


func join_profile(profile_id: StringName) -> bool:
	# Profil n'existe pas ou a déjà rejoint
	if not PROFILES.has(profile_id) or has_profile(profile_id):
		return false

	var player_number := _players.size() + 1
	var profile: Dictionary = PROFILES[profile_id]
	_players.append({
		"id": player_number,
		"name": "Joueur %d" % player_number,
		"profile_id": profile_id,
		"profile_name": profile["name"],
		"color": profile["color"],
	})
	players_changed.emit(get_players())
	return true


func has_profile(profile_id: StringName) -> bool:
	for player in _players:
		if player["profile_id"] == profile_id:
			return true
	return false


func get_player_for_profile(profile_id: StringName) -> Dictionary:
	for player in _players:
		if player["profile_id"] == profile_id:
			return player.duplicate(true)
	return {}


func get_players() -> Array[Dictionary]:
	return _players.duplicate(true)


func clear_players() -> void:
	if _players.is_empty():
		return
	_players.clear()
	players_changed.emit(get_players())
