class_name ClockCreature
extends Area2D

signal squashed(player_id: int)

# La créature ne fait qu'une courte patrouille sur sa plateforme.
@export var movement_speed := 72.0
@export var body_radius := 20.0

@onready var creature_visual: Node2D = %CreatureVisual

var _minimum_x := 0.0
var _maximum_x := 1920.0
var _movement_direction := 1.0
var _active := true


func setup(spawn_position: Vector2, minimum_x: float, maximum_x: float) -> void:
	# Les limites appartiennent à la plateforme qui porte la créature.
	position = spawn_position
	_minimum_x = minimum_x
	_maximum_x = maximum_x
	_movement_direction = -1.0 if randi() % 2 == 0 else 1.0


func _ready() -> void:
	# Area2D suffit : le joueur choisit entre écrasement et mauvais contact.
	body_entered.connect(_on_body_entered)
	# Chaque bestiole arrive avec un petit rebond visuel facile à repérer.
	creature_visual.scale = Vector2(0.72, 0.72)
	var appear_tween := create_tween()
	appear_tween.tween_property(creature_visual, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if not _active:
		return

	# La patrouille rebondit simplement aux deux extrémités de la plateforme.
	position.x += _movement_direction * movement_speed * delta
	if position.x <= _minimum_x:
		position.x = _minimum_x
		_movement_direction = 1.0
	elif position.x >= _maximum_x:
		position.x = _maximum_x
		_movement_direction = -1.0
	rotation = sin(Time.get_ticks_msec() * 0.009 + position.x) * 0.08


func _on_body_entered(body: Node2D) -> void:
	if not _active or not body is ClockJumper:
		return
	var jumper := body as ClockJumper
	if jumper.can_squash_creature(global_position.y):
		# La créature disparaît avant d'émettre pour empêcher un double comptage.
		_active = false
		set_deferred("monitoring", false)
		jumper.bounce_from_creature()
		squashed.emit(jumper.player.id)
		_play_squash_juice()
	else:
		jumper.hit_by_creature(global_position)


func set_movement_enabled(enabled: bool) -> void:
	# La fin de manche fige toutes les créatures encore visibles.
	_active = enabled
	set_deferred("monitoring", enabled)


func _play_squash_juice() -> void:
	# L'ennemi s'aplatit et s'efface avant d'être retiré de la scène.
	var squash_tween := create_tween()
	squash_tween.set_parallel(true)
	squash_tween.tween_property(creature_visual, "scale", Vector2(1.45, 0.12), 0.13).set_trans(Tween.TRANS_QUAD)
	squash_tween.tween_property(creature_visual, "modulate:a", 0.0, 0.13)
	await squash_tween.finished
	queue_free()
