class_name EnergyFragment
extends Area2D

signal collected(energy_fragment: EnergyFragment, player_star: SurvivalStar)

# L'objet se désactive dès le premier contact pour éviter deux collectes simultanées.
var _is_collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# Une rotation légère rend le fragment facile à repérer parmi les projectiles.
	rotation += delta * 1.8


func _on_body_entered(body: Node2D) -> void:
	if _is_collected or not body is SurvivalStar or not body.is_alive():
		return
	_is_collected = true
	set_deferred("monitoring", false)
	collected.emit(self, body)
