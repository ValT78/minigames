class_name BigAssMan
extends Node2D

@onready var body: Sprite2D = $Body
@onready var ass: Sprite2D = $Ass

var base_transform: Transform3D

# TODO mettre les beaux dessins de maxime + changer la logique de contracte pour l'animation des fesses
func _ready() -> void:
	base_transform = ass.global_transform
	decontracte()
	
func decontracte():
	pass

func contracte_gauche():
	pass
	
func contracte_droite():
	pass

func fesse_animation(player: LocalPlayer) -> void:
	if player.input.action_1_just_pressed:
		contracte_gauche()
	if player.input.action_2_just_pressed:
		contracte_droite()
		
