class_name DolphinRunner
extends CharacterBody2D

signal jellyfish_requested(dolphin: DolphinRunner, spawn_position: Vector2)

# Réglages principaux du déplacement et du mode express.
@export var movement_speed := 190.0
@export var movement_acceleration := 1250.0
@export var boost_speed := 1500.0
@export var boost_acceleration := 3500.0
@export var boost_turn_speed := 1.8
@export var jellyfish_cooldown := 2.0
@export var body_radius := 24.0

# Références visuelles adaptées à la couleur du joueur.
@onready var dolphin_visual: Node2D = %DolphinVisual
@onready var dolphin_body: Polygon2D = %DolphinBody
@onready var dolphin_belly: Polygon2D = %DolphinBelly
@onready var player_label: Label = %PlayerLabel
@onready var progress_label: Label = %ProgressLabel

# L'acteur conserve uniquement son joueur et ses états de mouvement locaux.
var player: LocalPlayer
var _arena_rect := Rect2()
var _movement_velocity := Vector2.ZERO
var _external_velocity := Vector2.ZERO
var _last_direction := Vector2.RIGHT
var _control_lock_left := 0.0
var _jellyfish_cooldown_left := 0.0
var _input_enabled := true


func setup(assigned_player: LocalPlayer, spawn_position: Vector2, arena_rect: Rect2) -> void:
	# L'association reste stable pendant toute la manche.
	player = assigned_player
	position = spawn_position
	_arena_rect = arena_rect
	_apply_player_style()


func _ready() -> void:
	# setup() peut précéder ou suivre l'entrée dans l'arbre.
	_apply_player_style()


func _physics_process(delta: float) -> void:
	if player == null:
		return

	# Les délais continuent même pendant une poussée ennemie.
	_control_lock_left = maxf(_control_lock_left - delta, 0.0)
	_jellyfish_cooldown_left = maxf(_jellyfish_cooldown_left - delta, 0.0)
	_external_velocity = _external_velocity.move_toward(Vector2.ZERO, 1050.0 * delta)

	# Une méduse est déposée une seule fois au début de l'appui.
	if (
		_input_enabled
		and _control_lock_left <= 0.0
		and player.input.action_2_just_pressed
		and _jellyfish_cooldown_left <= 0.0
	):
		_jellyfish_cooldown_left = jellyfish_cooldown
		var spawn_position := global_position - _last_direction * 42.0
		jellyfish_requested.emit(self, spawn_position)

	# La poussée retire brièvement le contrôle, puis le pilotage normal reprend.
	if not _input_enabled or _control_lock_left > 0.0:
		_movement_velocity = _movement_velocity.move_toward(Vector2.ZERO, movement_acceleration * delta)
	else:
		_update_controlled_movement(delta)

	velocity = _movement_velocity + _external_velocity
	move_and_slide()
	_keep_inside_arena()
	_update_visual_direction()


func _update_controlled_movement(delta: float) -> void:
	var requested_direction := player.input.direction
	if requested_direction.length_squared() > 0.01:
		requested_direction = requested_direction.normalized()

	# Le mode express accélère fort mais ne permet que des virages lents.
	if player.input.action_1_pressed:
		if requested_direction != Vector2.ZERO:
			var turn_weight := clampf(boost_turn_speed * delta, 0.0, 1.0)
			_last_direction = _last_direction.lerp(requested_direction, turn_weight).normalized()
		var target_velocity := _last_direction * boost_speed
		_movement_velocity = _movement_velocity.move_toward(target_velocity, boost_acceleration * delta)
		return

	# Hors boost, le dauphin suit directement les quatre directions génériques.
	if requested_direction != Vector2.ZERO:
		_last_direction = requested_direction
	var regular_target := requested_direction * movement_speed
	_movement_velocity = _movement_velocity.move_toward(
		regular_target,
		movement_acceleration * delta
	)


func apply_jellyfish_bump(origin: Vector2, strength: float, control_lock_duration: float) -> void:
	# La direction radiale garantit un rebond lisible quel que soit l'angle d'arrivée.
	var bump_direction := global_position - origin
	if bump_direction.length_squared() <= 0.01:
		bump_direction = -_last_direction
	_external_velocity = bump_direction.normalized() * strength
	_movement_velocity = Vector2.ZERO
	_control_lock_left = control_lock_duration


func update_progress(completed_ring_count: int, total_ring_count: int) -> void:
	# Le petit compteur rend la progression individuelle visible sur un parcours commun.
	progress_label.text = "%d/%d" % [completed_ring_count, total_ring_count]


func set_input_enabled(enabled: bool) -> void:
	# La fin de manche fige immédiatement toutes les commandes.
	_input_enabled = enabled
	if not enabled:
		_movement_velocity = Vector2.ZERO
		_external_velocity = Vector2.ZERO


func set_arena_rect(arena_rect: Rect2) -> void:
	_arena_rect = arena_rect
	_keep_inside_arena()


func _keep_inside_arena() -> void:
	# Le dauphin reste entièrement visible dans la zone de jeu.
	position.x = clampf(position.x, _arena_rect.position.x + body_radius, _arena_rect.end.x - body_radius)
	position.y = clampf(position.y, _arena_rect.position.y + body_radius, _arena_rect.end.y - body_radius)


func _update_visual_direction() -> void:
	# Seul le dessin tourne afin que les textes restent toujours droits.
	if _last_direction.length_squared() > 0.01:
		dolphin_visual.rotation = _last_direction.angle()


func _apply_player_style() -> void:
	if player == null or not is_node_ready():
		return
	# Deux nuances suffisent à identifier le joueur sans asset externe.
	dolphin_body.color = player.color
	dolphin_belly.color = player.color.lightened(0.48)
	player_label.text = "J%d" % player.id
	progress_label.modulate = player.color.lightened(0.35)
