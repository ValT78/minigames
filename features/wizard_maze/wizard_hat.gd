class_name WizardHat
extends CharacterBody2D

signal spell_requested(caster: WizardHat, direction: Vector2)
signal exit_reached(winner: WizardHat)

@export var movement_speed := 500.0
@export var teleport_cooldown := 1.8
@export var spell_cooldown := 0.85
@export var reverse_duration := 1.25
@export var hit_radius := 18.0

@onready var hat_visual: Node2D = %HatVisual
@onready var hat_cone: Polygon2D = %HatCone
@onready var hat_brim: Polygon2D = %HatBrim
@onready var hat_band: Polygon2D = %HatBand
@onready var direction_rune: Polygon2D = %DirectionRune
@onready var player_label: Label = %PlayerLabel
@onready var confusion_label: Label = %ConfusionLabel
@onready var teleport_gem: Polygon2D = %TeleportGem
@onready var spell_gem: Polygon2D = %SpellGem

var player: LocalPlayer
var _maze_board: WizardMazeBoard
var _last_pressed_direction := Vector2i.RIGHT
var _teleport_cooldown_left := 0.0
var _spell_cooldown_left := 0.0
var _reverse_time_left := 0.0
var _input_enabled := true
var _exit_already_reached := false


func setup(
	assigned_player: LocalPlayer,
	maze_board: WizardMazeBoard,
	spawn_position: Vector2,
) -> void:
	# Le même LocalPlayer reste associé au chapeau pendant toute la manche.
	player = assigned_player
	_maze_board = maze_board
	position = spawn_position
	_apply_player_style()
	_update_visual_state()


func _ready() -> void:
	# setup() peut être appelé avant ou après l'ajout dans l'arbre.
	_apply_player_style()
	_update_visual_state()


func _physics_process(delta: float) -> void:
	if player == null or _maze_board == null:
		return

	# Les trois délais restent locaux au chapeau et ne modifient jamais l'entrée globale.
	_teleport_cooldown_left = maxf(_teleport_cooldown_left - delta, 0.0)
	_spell_cooldown_left = maxf(_spell_cooldown_left - delta, 0.0)
	_reverse_time_left = maxf(_reverse_time_left - delta, 0.0)
	_remember_last_pressed_direction()

	if not _input_enabled:
		velocity = Vector2.ZERO
		_update_visual_state()
		return

	# Les actions ponctuelles sont traitées avant le déplacement du tick.
	if player.input.action_1_just_pressed:
		_try_teleport()
	if player.input.action_2_just_pressed:
		_try_cast_spell()

	# L'inversion est appliquée uniquement à l'interprétation locale des commandes.
	var requested_direction := player.input.direction
	if _is_reversed():
		requested_direction = -requested_direction
	velocity = requested_direction.limit_length(1.0) * movement_speed
	move_and_slide()
	_check_exit_reached()
	_update_visual_state()


func apply_reverse_controls(duration: float = -1.0) -> void:
	# Un nouveau sort rafraîchit l'effet sans empiler plusieurs inversions.
	_reverse_time_left = reverse_duration if duration < 0.0 else duration
	_update_visual_state()


func set_input_enabled(enabled: bool) -> void:
	# La fin de manche fige immédiatement le chapeau.
	_input_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO


func get_hit_radius() -> float:
	return hit_radius


func get_player_id() -> int:
	return player.id if player != null else -1


func _remember_last_pressed_direction() -> void:
	# Les impulsions cardinales préservent la dernière vraie touche, même en diagonale.
	if player.input.left_just_pressed:
		_last_pressed_direction = Vector2i.LEFT
	if player.input.right_just_pressed:
		_last_pressed_direction = Vector2i.RIGHT
	if player.input.up_just_pressed:
		_last_pressed_direction = Vector2i.UP
	if player.input.down_just_pressed:
		_last_pressed_direction = Vector2i.DOWN


func _try_teleport() -> void:
	if _teleport_cooldown_left > 0.0:
		return

	# La destination est le centre de la cellule voisine, même si un mur les sépare.
	var current_cell := _maze_board.world_to_cell(global_position)
	var effective_direction := Vector2i(_get_effective_last_direction())
	var destination_cell := current_cell + effective_direction
	if not _maze_board.is_cell_inside(destination_cell):
		return
	global_position = _maze_board.cell_to_world_center(destination_cell)
	velocity = Vector2.ZERO
	_teleport_cooldown_left = teleport_cooldown
	_play_teleport_feedback()


func _try_cast_spell() -> void:
	if _spell_cooldown_left > 0.0:
		return
	_spell_cooldown_left = spell_cooldown
	spell_requested.emit(self, _get_effective_last_direction())
	_play_spell_feedback()


func _get_effective_last_direction() -> Vector2:
	# Être désorienté inverse aussi la direction des deux pouvoirs.
	var direction := Vector2(_last_pressed_direction)
	return -direction if _is_reversed() else direction


func _is_reversed() -> bool:
	return _reverse_time_left > 0.0


func _check_exit_reached() -> void:
	if _exit_already_reached:
		return
	var exit_distance := global_position.distance_to(_maze_board.get_exit_position())
	if exit_distance > _maze_board.get_cell_size() * 0.27:
		return
	_exit_already_reached = true
	exit_reached.emit(self)


func _play_teleport_feedback() -> void:
	# Une brève dilatation rend le saut instantané visible malgré la vitesse.
	hat_visual.scale = Vector2(1.55, 0.55)
	var teleport_tween := create_tween()
	teleport_tween.set_trans(Tween.TRANS_BACK)
	teleport_tween.tween_property(hat_visual, "scale", Vector2.ONE, 0.18)


func _play_spell_feedback() -> void:
	# Le chapeau se penche dans le sens du tir puis revient à sa pose normale.
	hat_visual.rotation = _get_effective_last_direction().angle() * 0.12
	var spell_tween := create_tween()
	spell_tween.tween_property(hat_visual, "rotation", 0.0, 0.16)


func _update_visual_state() -> void:
	if not is_node_ready():
		return
	# La rune montre la direction mémorisée, tandis que les gemmes indiquent les recharges.
	direction_rune.rotation = _get_effective_last_direction().angle()
	confusion_label.visible = _is_reversed()
	hat_visual.modulate = Color("d7a8ff") if _is_reversed() else Color.WHITE
	teleport_gem.modulate.a = 1.0 if _teleport_cooldown_left <= 0.0 else 0.22
	spell_gem.modulate.a = 1.0 if _spell_cooldown_left <= 0.0 else 0.22


func _apply_player_style() -> void:
	if player == null or not is_node_ready():
		return
	# La couleur du lobby teinte le chapeau sans modifier sa silhouette magique.
	hat_cone.color = player.color.darkened(0.12)
	hat_brim.color = player.color.darkened(0.3)
	hat_band.color = player.color.lightened(0.42)
	player_label.text = "J%d" % (player.id + 1)
	player_label.modulate = player.color.lightened(0.35)
	teleport_gem.color = player.color.lightened(0.45)
	spell_gem.color = Color("d987ff")
