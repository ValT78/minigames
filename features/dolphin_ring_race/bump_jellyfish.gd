class_name BumpJellyfish
extends Area2D

# Réglages courts pour garder le piège dangereux sans bloquer l'arène.
@export var lifetime := 1.5
@export var bump_strength := 820.0
@export var control_lock_duration := 0.35

# L'identifiant empêche uniquement le propriétaire de déclencher sa méduse.
var _owner_player_id := 0
var _life_left := 0.0
var _jellyfish_color := Color("7de3ff")
var _consumed := false

@onready var jellyfish_glow: Polygon2D = %JellyfishGlow
@onready var jellyfish_body: Polygon2D = %JellyfishBody
@onready var dome_outline: Line2D = %DomeOutline
@onready var tentacle_container: Node2D = %TentacleContainer


func setup(owner_player_id: int, spawn_position: Vector2, player_color: Color) -> void:
	# La méduse reprend une nuance du joueur qui l'a déposée.
	_owner_player_id = owner_player_id
	global_position = spawn_position
	_jellyfish_color = player_color.lightened(0.35)
	_life_left = lifetime
	_apply_player_style()


func _ready() -> void:
	# Une Area2D suffit car le contact ne doit pas bloquer physiquement les joueurs.
	body_entered.connect(_on_body_entered)
	if _life_left <= 0.0:
		_life_left = lifetime
	_apply_player_style()


func _process(delta: float) -> void:
	# La pulsation rend la courte durée de vie visible sans animation externe.
	_life_left = maxf(_life_left - delta, 0.0)
	scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.08)
	modulate.a = clampf(_life_left / 0.3, 0.0, 1.0)
	if _life_left <= 0.0:
		queue_free()


func _apply_player_style() -> void:
	if not is_node_ready():
		return
	# La scène contient le dessin ; le script change seulement ses couleurs à l'instanciation.
	jellyfish_glow.color = Color(_jellyfish_color, 0.28)
	jellyfish_body.color = Color(_jellyfish_color, 0.72)
	dome_outline.default_color = _jellyfish_color
	for tentacle in tentacle_container.get_children():
		if tentacle is Line2D:
			(tentacle as Line2D).default_color = _jellyfish_color


func _on_body_entered(body: Node2D) -> void:
	if _consumed or not body is DolphinRunner:
		return
	var dolphin := body as DolphinRunner
	if dolphin.player == null or dolphin.player.id == _owner_player_id:
		return

	# Le premier adversaire touché consomme la méduse et reçoit la poussée.
	_consumed = true
	set_deferred("monitoring", false)
	dolphin.apply_jellyfish_bump(global_position, bump_strength, control_lock_duration)
	queue_free()
