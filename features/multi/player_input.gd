class_name PlayerInput
extends RefCounted

## Direction normalisée entre -1 et 1, identique pour clavier et souris.
var movement := Vector2.ZERO
## Reste vrai tant que le bouton de saut est maintenu.
var jump_pressed := false
## N'est vrai que pendant le premier tick physique de l'appui.
var jump_just_pressed := false
## N'est vrai que pendant le tick où le dash est demandé.
var dash_just_pressed := false


# Limite le vecteur pour empêcher les diagonales d'être plus rapides.
func _set_movement(value: Vector2) -> void:
	movement = value.limit_length(1.0)


# Mémorise à la fois l'état maintenu et le début d'un nouvel appui.
func _set_jump_pressed(pressed: bool) -> void:
	if pressed and not jump_pressed:
		jump_just_pressed = true
	jump_pressed = pressed


# Le dash est une impulsion : le maintenir ne répète pas automatiquement l'action.
func _press_dash() -> void:
	dash_just_pressed = true


# Efface les impulsions après que les éléments de jeu ont pu les lire.
func _finish_physics_frame() -> void:
	jump_just_pressed = false
	dash_just_pressed = false
