class_name RouteRing
extends Area2D

signal dolphin_entered(route_index: int, dolphin: DolphinRunner)

# Le cerceau connaît seulement sa place dans le parcours commun.
var route_index := 0
var _pulse_time := 0.0
var _reveal_scale := 0.0

@onready var ring_number_label: Label = %RingNumberLabel


func setup(index: int, ring_position: Vector2) -> void:
	# Les cerceaux sont prépositionnés mais restent inactifs avant leur révélation.
	route_index = index
	position = ring_position
	ring_number_label.text = str(index + 1)
	visible = false
	monitoring = false


func _ready() -> void:
	# Le signal physique reste local au cerceau.
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not visible:
		return
	# Une pulsation douce différencie clairement les objectifs des décors.
	_pulse_time += delta
	_reveal_scale = minf(_reveal_scale + delta * 4.5, 1.0)
	var pulse_scale := 1.0 + sin(_pulse_time * 4.0) * 0.045
	scale = Vector2.ONE * pulse_scale * _reveal_scale


func reveal() -> void:
	# L'échelle monte progressivement pendant que la collision est activée en différé.
	visible = true
	_reveal_scale = 0.05
	scale = Vector2.ONE * _reveal_scale
	set_deferred("monitoring", true)


func flash(player_color: Color) -> void:
	# Le flash confirme le passage sans masquer le numéro du cerceau.
	var flash_tween := create_tween()
	modulate = player_color.lightened(0.3)
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.3)


func _on_body_entered(body: Node2D) -> void:
	if body is DolphinRunner:
		dolphin_entered.emit(route_index, body as DolphinRunner)
