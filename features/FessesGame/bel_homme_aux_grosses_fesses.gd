class_name BigAssMan
extends Node2D

@onready var body: Sprite2D = $Body
@onready var ass: Sprite2D = $Ass
@onready var transform_left: Marker2D = $TransformLeft
@onready var transform_right: Marker2D = $TransformRight
@onready var base_transform := ass.global_transform

@export var anim_duration: float = 0.05

var _tween: Tween

func _ready() -> void:
	decontracte()

func _tween_to(target_transform: Transform2D, duration: float = anim_duration) -> void:
	_tween = create_tween()
	_tween.tween_property(ass, "global_transform", target_transform, duration) \
		  .set_trans(Tween.TRANS_SINE) \
		  .set_ease(Tween.EASE_IN_OUT)

func decontracte() -> void:
	_tween_to(base_transform)

func contracte_gauche() -> void:
	_tween_to(transform_left.global_transform)

func contracte_droite() -> void:
	_tween_to(transform_right.global_transform)

func fesse_animation(player: LocalPlayer) -> void:
	if player.input.action_1_just_pressed:
		contracte_gauche()
	if player.input.action_2_just_pressed:
		contracte_droite()
