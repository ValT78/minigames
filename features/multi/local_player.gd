class_name LocalPlayer
extends RefCounted

# Informations stables qui identifient le joueur pendant toute la session.
var id: int
var display_name: String
var profile_id: StringName
var profile_name: String
var color: Color

# État normalisé des commandes, mis à jour par PlayerRegistry.
var input := PlayerInput.new()


## Construit un joueur à partir du profil physique qui lui a été attribué.
func _init(
	player_id: int,
	player_name: String,
	assigned_profile_id: StringName,
	assigned_profile_name: String,
	player_color: Color,
) -> void:
	id = player_id
	display_name = player_name
	profile_id = assigned_profile_id
	profile_name = assigned_profile_name
	color = player_color
