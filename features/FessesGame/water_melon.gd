class_name WaterMelon
extends Node2D

@onready var water_melon_full: Sprite2D = $WaterMelonFull
@onready var water_melon_exploded: Sprite2D = $WaterMelonExploded
@onready var despawn_timer: Timer = $Timer
@onready var particles: Sprite2D = $WaterMelonExploded/Particles

var exploded := false
var big_ass_man : BigAssMan

func crush(player_how_crushed : int) -> void:
	water_melon_exploded.visible = true
	water_melon_full.visible = false
	
	exploded = true
	particles.modulate = Globals.player_0_color if player_how_crushed == 0 else Globals.player_1_color
	despawn_timer.start()

func _on_timer_timeout() -> void:
	big_ass_man.decontracte()
	queue_free()
