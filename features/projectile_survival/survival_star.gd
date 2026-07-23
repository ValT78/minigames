class_name SurvivalStar
extends CharacterBody2D

signal eliminated(player_star: SurvivalStar)

# Réglages principaux accessibles aux game designers dans l'inspecteur.
@export var movement_speed := 330.0
@export var dash_speed := 860.0
@export var dash_duration := 0.24
@export var dash_cooldown := 1.05
@export var repulsion_range := 165.0
@export var repulsion_strength := 520.0
@export var repulsion_cooldown := 1.35
@export var repulsion_friction := 1050.0
@export var body_radius := 22.0

# Le corps et le numéro sont personnalisés à partir du LocalPlayer associé.
@onready var star_visuals: Node2D = %StarVisuals
@onready var star_body: Polygon2D = %StarBody
@onready var star_core: Polygon2D = %StarCore
@onready var player_label: Label = %PlayerLabel
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var dash_trace: Line2D = %DashTrace

# Les états courts restent locaux à l'acteur et indépendants des touches physiques.
var player: LocalPlayer
var _arena_rect := Rect2()
var _last_direction := Vector2.UP
var _external_velocity := Vector2.ZERO
var _dash_direction := Vector2.ZERO
var _dash_origin := Vector2.ZERO
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _repulsion_cooldown_left := 0.0
var _repulsion_visual_time_left := 0.0
var _alive := true
var _input_enabled := true


func setup(assigned_player: LocalPlayer, spawn_position: Vector2, arena_rect: Rect2) -> void:
	# setup() est appelé juste après l'ajout dans la scène principale.
	player = assigned_player
	position = spawn_position
	_arena_rect = arena_rect
	_apply_player_style()


func _physics_process(delta: float) -> void:
	if player == null or not _alive:
		return

	# Les recharges continuent pendant le dash afin de garder un rythme prévisible.
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_repulsion_cooldown_left = maxf(_repulsion_cooldown_left - delta, 0.0)
	_update_repulsion_visual(delta)

	# Les actions ponctuelles sont lues pendant le tick physique, comme prévu par le routeur.
	if _input_enabled and not is_dashing():
		if player.input.action_1_just_pressed and _dash_cooldown_left <= 0.0:
			_start_dash()
		elif player.input.action_2_just_pressed and _repulsion_cooldown_left <= 0.0:
			_emit_repulsion_wave()

	# Le dash conserve sa direction, sinon le joueur retrouve immédiatement son contrôle.
	if is_dashing():
		_update_dash(delta)
	else:
		_update_regular_movement(delta)

	move_and_slide()
	_keep_inside_arena()


func _update_regular_movement(delta: float) -> void:
	var input_direction := Vector2.ZERO
	if _input_enabled:
		input_direction = player.input.direction
	if input_direction.length_squared() > 0.01:
		_last_direction = input_direction.normalized()

	# Une poussée décroissante s'ajoute au mouvement sans retirer tout contrôle à la cible.
	_external_velocity = _external_velocity.move_toward(Vector2.ZERO, repulsion_friction * delta)
	velocity = input_direction * movement_speed + _external_velocity


func _start_dash() -> void:
	# Sans direction tenue, l'éclipse reprend la dernière orientation connue.
	var requested_direction := player.input.direction
	_dash_direction = requested_direction.normalized()
	if _dash_direction == Vector2.ZERO:
		_dash_direction = _last_direction
	_dash_origin = global_position
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	_external_velocity = Vector2.ZERO
	star_visuals.visible = false
	dash_trace.visible = true


func _update_dash(delta: float) -> void:
	_dash_time_left = maxf(_dash_time_left - delta, 0.0)
	velocity = _dash_direction * dash_speed

	# La trace indique le trajet alors que l'étoile elle-même a disparu.
	dash_trace.points = PackedVector2Array([
		to_local(_dash_origin),
		Vector2.ZERO,
	])
	if _dash_time_left <= 0.0:
		star_visuals.visible = true
		dash_trace.visible = false


func _emit_repulsion_wave() -> void:
	_repulsion_cooldown_left = repulsion_cooldown
	_repulsion_visual_time_left = 0.22
	queue_redraw()

	# Le groupe local évite une couche physique supplémentaire pour une impulsion ponctuelle.
	for other_star in get_tree().get_nodes_in_group(&"survival_players"):
		if other_star == self or not other_star is SurvivalStar:
			continue
		if not other_star.is_alive() or other_star.is_dashing():
			continue

		var offset: Vector2 = other_star.global_position - global_position
		if offset.length() <= repulsion_range:
			var push_direction := offset.normalized()
			if push_direction == Vector2.ZERO:
				push_direction = _last_direction
			other_star.apply_repulsion(push_direction * repulsion_strength)


func _update_repulsion_visual(delta: float) -> void:
	if _repulsion_visual_time_left <= 0.0:
		return
	_repulsion_visual_time_left = maxf(_repulsion_visual_time_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	# L'onde s'élargit puis s'efface sans créer de nœud temporaire.
	if _repulsion_visual_time_left <= 0.0:
		return
	var progress := 1.0 - _repulsion_visual_time_left / 0.22
	var wave_radius := lerpf(body_radius, repulsion_range, progress)
	var wave_color := player.color if player != null else Color.WHITE
	wave_color.a = (1.0 - progress) * 0.75
	draw_arc(Vector2.ZERO, wave_radius, 0.0, TAU, 64, wave_color, 7.0)


func apply_repulsion(repulsion_velocity: Vector2) -> void:
	# Plusieurs ondes proches peuvent se combiner, avec une limite contre les vitesses extrêmes.
	_external_velocity = (_external_velocity + repulsion_velocity).limit_length(
		repulsion_strength * 1.5
	)


func try_eliminate() -> bool:
	# Une étoile éclipsée ou déjà éteinte ignore entièrement l'astéroïde.
	if not _alive or is_dashing():
		return false
	_alive = false
	velocity = Vector2.ZERO
	_external_velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)
	star_visuals.modulate = Color(0.5, 0.55, 0.72, 0.28)
	player_label.text = "✦"
	eliminated.emit(self)
	return true


func is_alive() -> bool:
	return _alive


func is_dashing() -> bool:
	return _dash_time_left > 0.0


func set_input_enabled(enabled: bool) -> void:
	# Le résultat de manche fige les nouvelles actions tout en terminant proprement le mouvement.
	_input_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		_external_velocity = Vector2.ZERO


func set_arena_rect(arena_rect: Rect2) -> void:
	_arena_rect = arena_rect
	_keep_inside_arena()


func _keep_inside_arena() -> void:
	# La marge du corps empêche le visuel de traverser la bordure de l'arène.
	position.x = clampf(position.x, _arena_rect.position.x + body_radius, _arena_rect.end.x - body_radius)
	position.y = clampf(position.y, _arena_rect.position.y + body_radius, _arena_rect.end.y - body_radius)


func _apply_player_style() -> void:
	if player == null or not is_node_ready():
		return
	# Une teinte claire au centre garde chaque étoile lisible sur le fond sombre.
	star_body.color = player.color
	star_core.color = player.color.lightened(0.55)
	dash_trace.default_color = player.color
	player_label.text = "J%d" % player.id
