class_name WaterMelonTaiko
extends Area2D

@export var speed := 600
@onready var water_melon_full: Sprite2D = $WaterMelonFull
@onready var water_melon_exploded: Sprite2D = $WaterMelonExploded
@onready var despawn_timer: Timer = $Timer
@onready var particles: Sprite2D = $WaterMelonExploded/Particles

var exploded := false

func crush(player_how_crushed : LocalPlayer) -> void:
	water_melon_exploded.visible = true
	water_melon_full.visible = false
	
	exploded = true
	particles.modulate = player_how_crushed.color
	despawn_timer.start()

func _on_timer_timeout() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	position.x -= delta * speed
