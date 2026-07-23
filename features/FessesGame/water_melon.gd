class_name WaterMelon
extends Node2D

@onready var water_melon_full: Sprite2D = $WaterMelonFull
@onready var water_melon_exploded: Sprite2D = $WaterMelonExploded
@onready var despawn_timer: Timer = $Timer

var exploded := false

func crush() -> void:
	water_melon_exploded.visible = true
	water_melon_full.visible = false
	
	exploded = true
	despawn_timer.start()

func _on_timer_timeout() -> void:
	queue_free()
