class_name BigAssMan
extends Node2D

@onready var idle: Sprite2D = $Idle
@onready var fesse_droite: Sprite2D = $FesseDroite
@onready var fesse_gauche: Sprite2D = $FesseGauche

# TODO mettre les beaux dessins de maxime + changer la logique de contracte pour l'animation des fesses
func _ready() -> void:
	decontracte()
	
func decontracte():
	idle.visible = true
	fesse_droite.visible = false
	fesse_gauche.visible = false

func contracte_gauche():
	idle.visible = false
	fesse_droite.visible = false
	fesse_gauche.visible = true
	
func contracte_droite():
	idle.visible = false
	fesse_droite.visible = true
	fesse_gauche.visible = false

func fesse_animation(player: LocalPlayer) -> void:
	if player.input.action_1_just_pressed:
		contracte_gauche()
	if player.input.action_2_just_pressed:
		contracte_droite()
		
