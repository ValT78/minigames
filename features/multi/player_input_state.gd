class_name PlayerInputState
extends RefCounted

## Direction normalisée entre -1 et 1, identique pour tous les périphériques.
var direction := Vector2.ZERO

## États continu et ponctuel de la première action générique.
var action_1_pressed := false
var action_1_just_pressed := false

## États continu et ponctuel de la seconde action générique.
var action_2_pressed := false
var action_2_just_pressed := false


# Limite le vecteur pour empêcher les diagonales d'être plus rapides.
func _set_direction(value: Vector2) -> void:
	direction = value.limit_length(1.0)


# Conserve l'état maintenu et détecte le début d'un nouvel appui.
func _set_action_1_pressed(pressed: bool) -> void:
	if pressed and not action_1_pressed:
		action_1_just_pressed = true
	action_1_pressed = pressed


# Les deux actions proposent la même API afin de rester interchangeables.
func _set_action_2_pressed(pressed: bool) -> void:
	if pressed and not action_2_pressed:
		action_2_just_pressed = true
	action_2_pressed = pressed


# Les impulsions sont effacées après lecture par les éléments de jeu.
func _finish_physics_frame() -> void:
	action_1_just_pressed = false
	action_2_just_pressed = false
