class_name TaikoGameLine
extends Node2D

var player : LocalPlayer
@export var press_line_area: Area2D
@onready var ass_idle: Marker2D = $AssIdle
@onready var ass_crush_1: Marker2D = $AssCrush1
@onready var ass_crush_2: Marker2D = $AssCrush2
@onready var label: Label = $PlayerScore/Label
@onready var count: Label = $PlayerScore/Count
@onready var ass: Sprite2D = $Ass
@export var anim_duration: float = 0.05

var tween: Tween

func _ready() -> void:
	label.text = "Player 1" if player.id == 0 else "Player 2"

func ass_crush_animation() -> void:
	var down_transform := ass_crush_1.global_transform if randf() < 0.5 else ass_crush_2.global_transform
	tween = create_tween()
	tween.tween_property(ass, "global_transform", down_transform, anim_duration/2) \
		  .set_trans(Tween.TRANS_SINE) \
		  .set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ass, "global_transform", ass_idle.global_transform, anim_duration) \
		  .set_trans(Tween.TRANS_SINE) \
		  .set_ease(Tween.EASE_IN_OUT)

func update_count_text(new_count: int) -> void:
	count.text = str(new_count)
