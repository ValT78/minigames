class_name ChickenSlingshot
extends Node2D

signal round_won(winner_player_id: int)
signal round_lost

# Réglages principaux calibrés pour la manche de dix secondes du Backbone.
@export_range(1, 12, 1) var chickens_to_win := 5
@export_range(1.0, 9.0, 0.5) var arrow_grant_time_left := 5.0
@export_range(5.0, 30.0, 1.0) var direct_test_duration := 10.0
@export_range(40.0, 180.0, 1.0) var arena_margin := 82.0
@export_range(0.15, 0.35, 0.01) var fence_position_ratio := 0.22
@export var create_test_players_when_running_directly := true

# Toutes les scènes utilisées par le jeu restent dans le dossier de la feature.
const HUNTER_SCENE := preload("res://features/chicken_slingshot/chicken_hunter.tscn")
const CHICKEN_SCENE := preload("res://features/chicken_slingshot/field_chicken.tscn")
const PROJECTILE_SCENE := preload("res://features/chicken_slingshot/slingshot_projectile.tscn")

@onready var player_side: ColorRect = %PlayerSide
@onready var field_side: ColorRect = %FieldSide
@onready var fence_back: Line2D = %FenceBack
@onready var fence_front: Line2D = %FenceFront
@onready var fence_highlight: Line2D = %FenceHighlight
@onready var chicken_container: Node2D = %ChickenContainer
@onready var projectile_container: Node2D = %ProjectileContainer
@onready var player_container: Node2D = %PlayerContainer
@onready var score_row: HBoxContainer = %ScoreRow
@onready var local_time_label: Label = %LocalTimeLabel
@onready var arrow_announcement: PanelContainer = %ArrowAnnouncement
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel

# Le contrôleur conserve uniquement les acteurs et scores utiles à la manche courante.
var _hunters: Dictionary[int, ChickenHunter] = {}
var _score_labels: Dictionary[int, Label] = {}
var _chicken_scores: Dictionary[int, int] = {}
var _arena_rect := Rect2()
var _field_rect := Rect2()
var _fence_x := 0.0
var _elapsed_time := 0.0
var _round_finished := false
var _arrow_granted := false
var _uses_external_timer := false


func _ready() -> void:
	# Le timer global n'est utilisé que lorsque le Backbone a ajouté cette scène.
	_uses_external_timer = get_tree().current_scene != self
	_create_direct_test_players_if_needed()
	local_time_label.visible = not _uses_external_timer
	if _uses_external_timer:
		GameManager.round_timer_expired.connect(_on_round_timer_expired)
	get_viewport().size_changed.connect(_layout_arena)

	# Les limites doivent exister avant de placer les joueurs et les poules.
	_layout_arena()
	_spawn_all_players()
	_spawn_all_chickens()
	_update_hud()


func _exit_tree() -> void:
	# Les connexions globales ne doivent pas survivre au changement de mini-jeu.
	if get_viewport().size_changed.is_connected(_layout_arena):
		get_viewport().size_changed.disconnect(_layout_arena)
	if GameManager.round_timer_expired.is_connected(_on_round_timer_expired):
		GameManager.round_timer_expired.disconnect(_on_round_timer_expired)


func _process(delta: float) -> void:
	if _round_finished:
		return

	# Le temps local garde la scène testable sans dupliquer le timer en production.
	_elapsed_time = minf(_elapsed_time + delta, direct_test_duration)
	var time_left := _get_time_left()
	if not _arrow_granted and time_left <= arrow_grant_time_left:
		_grant_special_arrows()
	_update_hud()
	if not _uses_external_timer and _elapsed_time >= direct_test_duration:
		_on_round_timer_expired()


func _create_direct_test_players_if_needed() -> void:
	# Deux profils suffisent pour vérifier la compétition lors d'un lancement direct.
	if not create_test_players_when_running_directly:
		return
	if get_tree().current_scene != self or not PlayerRegistry.get_players().is_empty():
		return
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_RIGHT)
	PlayerRegistry.join_profile(PlayerRegistry.MOUSE)


func _spawn_all_players() -> void:
	var players := PlayerRegistry.get_players()
	if players.is_empty():
		push_warning("ChickenSlingshot démarre sans joueur inscrit.")
		return

	# Tous les joueurs restent derrière la clôture et sont répartis sur sa hauteur.
	for player_index in players.size():
		var player: LocalPlayer = players[player_index]
		var spawn_y := _arena_rect.position.y + (
			_arena_rect.size.y * float(player_index + 1) / float(players.size() + 1)
		)
		var spawn_position := Vector2(_fence_x - 105.0, spawn_y)

		var hunter: ChickenHunter = HUNTER_SCENE.instantiate()
		_hunters[player.id] = hunter
		_chicken_scores[player.id] = 0
		player_container.add_child(hunter)
		hunter.setup(player, spawn_position, _arena_rect)
		hunter.projectile_requested.connect(_on_projectile_requested)
		_create_score_label(player)


func _create_score_label(player: LocalPlayer) -> void:
	# Un compteur coloré permet de suivre les cinq prises sans toucher au score global.
	var score_label := Label.new()
	score_label.custom_minimum_size = Vector2(170.0, 48.0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 25)
	score_label.add_theme_color_override("font_color", player.color.lightened(0.25))
	score_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.12, 0.04, 0.9))
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	score_row.add_child(score_label)
	_score_labels[player.id] = score_label


func _spawn_all_chickens() -> void:
	var players := PlayerRegistry.get_players()
	var chicken_count := chickens_to_win * players.size()
	if chicken_count <= 0:
		return

	# Une grille légèrement irrégulière évite les superpositions tout en gardant un champ vivant.
	var field_aspect := _field_rect.size.x / maxf(_field_rect.size.y, 1.0)
	var column_count := maxi(1, ceili(sqrt(float(chicken_count) * field_aspect)))
	var row_count := ceili(float(chicken_count) / float(column_count))
	var cell_size := Vector2(
		_field_rect.size.x / float(column_count),
		_field_rect.size.y / float(row_count),
	)
	for chicken_index in chicken_count:
		var column := chicken_index % column_count
		var row := floori(float(chicken_index) / float(column_count))
		var spawn_position := _field_rect.position + Vector2(
			(float(column) + 0.5) * cell_size.x,
			(float(row) + 0.5) * cell_size.y,
		)
		spawn_position += Vector2(
			randf_range(-cell_size.x, cell_size.x) * 0.18,
			randf_range(-cell_size.y, cell_size.y) * 0.18,
		)

		var chicken: FieldChicken = CHICKEN_SCENE.instantiate()
		chicken_container.add_child(chicken)
		chicken.setup(spawn_position, _field_rect)
		chicken.killed.connect(_on_chicken_killed)


func _on_projectile_requested(
	player_id: int,
	spawn_position: Vector2,
	travel_direction: Vector2,
	charge_ratio: float,
	is_arrow: bool,
) -> void:
	if _round_finished:
		return

	# Le même projectile est configuré en caillou balistique ou en flèche perforante.
	var projectile: SlingshotProjectile = PROJECTILE_SCENE.instantiate()
	projectile.setup(
		player_id,
		spawn_position,
		travel_direction,
		charge_ratio,
		is_arrow,
		get_viewport_rect(),
	)
	projectile_container.add_child(projectile)


func _on_chicken_killed(player_id: int) -> void:
	if _round_finished or not _chicken_scores.has(player_id):
		return

	# Le premier joueur à cinq verrouille immédiatement tous les impacts suivants.
	_chicken_scores[player_id] += 1
	_update_score_label(player_id)
	if _chicken_scores[player_id] >= chickens_to_win:
		_finish_round(player_id)


func _grant_special_arrows() -> void:
	if _round_finished or _arrow_granted:
		return
	_arrow_granted = true

	# Chaque joueur reçoit exactement une flèche et une annonce commune la rend évidente.
	for hunter in _hunters.values():
		hunter.grant_arrow()
	arrow_announcement.visible = true
	arrow_announcement.modulate.a = 1.0
	arrow_announcement.scale = Vector2(0.72, 0.72)
	var announcement_tween := create_tween()
	announcement_tween.set_parallel(true)
	announcement_tween.tween_property(arrow_announcement, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	announcement_tween.tween_property(arrow_announcement, "modulate:a", 0.0, 1.35).set_delay(0.75)
	announcement_tween.chain().tween_callback(func() -> void: arrow_announcement.visible = false)


func _on_round_timer_expired() -> void:
	if _round_finished:
		return
	_finish_round(0)


func _finish_round(winner_player_id: int) -> void:
	if _round_finished:
		return
	_round_finished = true

	# Tout est figé avant d'appeler le Backbone afin d'éviter une victoire au dernier tick.
	for hunter in _hunters.values():
		hunter.set_input_enabled(false)
	for chicken in chicken_container.get_children():
		if chicken is FieldChicken:
			(chicken as FieldChicken).set_movement_enabled(false)
	for projectile in projectile_container.get_children():
		projectile.queue_free()

	# En test direct le panneau reste affiché ; intégré, le Backbone enchaîne la scène.
	result_panel.visible = true
	if winner_player_id > 0:
		var winner := _get_player_by_id(winner_player_id)
		result_label.text = "%s REMPORTE LA CHASSE !" % (
			winner.display_name.to_upper() if winner != null else "UN JOUEUR"
		)
		if winner != null:
			result_label.modulate = winner.color.lightened(0.25)
		round_won.emit(winner_player_id)
		if _uses_external_timer:
			GameManager.minigameWon(winner_player_id)
	else:
		result_label.text = "PERDU !"
		round_lost.emit()
		if _uses_external_timer:
			GameManager.minigameLost()


func _get_player_by_id(player_id: int) -> LocalPlayer:
	for player in PlayerRegistry.get_players():
		if player.id == player_id:
			return player
	return null


func _layout_arena() -> void:
	# La clôture réserve une bande fixe aux tireurs quelle que soit la taille de fenêtre.
	var viewport_size := get_viewport_rect().size
	var safe_margin := minf(arena_margin, minf(viewport_size.x, viewport_size.y) * 0.16)
	_arena_rect = Rect2(
		Vector2(safe_margin, safe_margin),
		viewport_size - Vector2.ONE * safe_margin * 2.0,
	)
	_fence_x = clampf(
		viewport_size.x * fence_position_ratio,
		_arena_rect.position.x + 190.0,
		_arena_rect.end.x - 500.0,
	)
	_field_rect = Rect2(
		Vector2(_fence_x + 75.0, _arena_rect.position.y + 42.0),
		Vector2(_arena_rect.end.x - _fence_x - 105.0, _arena_rect.size.y - 84.0),
	)

	# Les deux aplats et les deux traits suffisent à matérialiser clairement la clôture.
	player_side.position = Vector2.ZERO
	player_side.size = Vector2(_fence_x, viewport_size.y)
	field_side.position = Vector2(_fence_x, 0.0)
	field_side.size = Vector2(viewport_size.x - _fence_x, viewport_size.y)
	var fence_points := PackedVector2Array([
		Vector2(_fence_x, _arena_rect.position.y),
		Vector2(_fence_x, _arena_rect.end.y),
	])
	fence_back.points = fence_points
	fence_front.points = fence_points
	fence_highlight.points = PackedVector2Array([
		Vector2(_fence_x - 6.0, _arena_rect.position.y),
		Vector2(_fence_x - 6.0, _arena_rect.end.y),
	])

	# Les acteurs déjà présents restent dans leurs nouvelles limites après redimensionnement.
	for hunter in _hunters.values():
		hunter.set_vertical_bounds(_arena_rect.position.y, _arena_rect.end.y)
	for chicken in chicken_container.get_children():
		if chicken is FieldChicken:
			(chicken as FieldChicken).set_field_rect(_field_rect)


func _get_time_left() -> float:
	if _uses_external_timer:
		return GameManager.get_time_left()
	return maxf(direct_test_duration - _elapsed_time, 0.0)


func _update_hud() -> void:
	# Le compteur local disparaît lorsque le HUD global du Backbone est disponible.
	local_time_label.text = "%02d" % ceili(_get_time_left())
	for player_id in _score_labels:
		_update_score_label(player_id)


func _update_score_label(player_id: int) -> void:
	if not _score_labels.has(player_id):
		return
	_score_labels[player_id].text = "J%d  %d/%d" % [
		player_id,
		_chicken_scores.get(player_id, 0),
		chickens_to_win,
	]
