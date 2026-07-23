extends Node2D

@onready var idle: Sprite2D = $Idle
@onready var fesse_droite: Sprite2D = $FesseDroite
@onready var fesse_gauche: Sprite2D = $FesseGauche

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	idle.visible = true
	fesse_droite.visible = false
	fesse_gauche.visible = false

func _contracte_gauche():
	idle.visible = false
	fesse_droite.visible = false
	fesse_gauche.visible = true
	
func _contracte_droite():
	idle.visible = false
	fesse_droite.visible = true
	fesse_gauche.visible = false

func fesse_animation(input_dir: Vector2) -> void:
	if input_dir.x == 0:
		return

	if input_dir.x < 0:
		print("ANIMATION FESSE GAUCHE")
		_contracte_gauche()

	if input_dir.x > 0:
		print("ANIMATION FESSE DROITE")
		_contracte_droite()
