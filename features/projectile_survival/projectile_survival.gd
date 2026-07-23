class_name ProjectileSurvival
extends Node2D

signal round_won
signal round_lost

# Paramètres de manche modifiables sans toucher au générateur d'astéroïdes.
@export_range(5.0, 120.0, 1.0) var survival_duration := 20.0
@export_range(40.0, 180.0, 1.0) var arena_margin := 84.0
@export var create_test_player_when_running_directly := true

# Les acteurs restent entièrement contenus dans cette feature.
const SURVIVAL_STAR_SCENE := preload("res://features/projectile_survival/survival_star.tscn")

@onready var arena_border: Line2D = %ArenaBorder
@onready var asteroid_container: Node2D = %AsteroidContainer
@onready var player_container: Node2D = %PlayerContainer
@onready var asteroid_spawner: AsteroidSpawner = %AsteroidSpawner
@onready var time_label: Label = %TimeLabel
@onready var remaining_label: Label = %RemainingLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel

# La scène conserve ses acteurs afin de compter les survivants sans interroger le registre.
var _player_stars: Dictionary[int, SurvivalStar] = {}
var _arena_rect := Rect2()
var _elapsed_time := 0.0
var _round_finished := false


func _ready() -> void:
	# La scène directe crée un joueur de test, tandis qu'une partie normale utilise le lobby.
	_create_direct_test_player_if_needed()
	get_viewport().size_changed.connect(_layout_arena)
	_layout_arena()
	_spawn_all_players()
	asteroid_spawner.setup(_arena_rect, survival_duration, asteroid_container)
	_update_hud()


func _exit_tree() -> void:
	# Évite de conserver une connexion vers une scène retirée par le Backbone.
	if get_viewport().size_changed.is_connected(_layout_arena):
		get_viewport().size_changed.disconnect(_layout_arena)


func _process(delta: float) -> void:
	if _round_finished:
		return

	# Le temps local rend la scène testable avant son raccordement au GameManager.
	_elapsed_time = minf(_elapsed_time + delta, survival_duration)
	_update_hud()
	if _elapsed_time >= survival_duration:
		_finish_round(true)


func _create_direct_test_player_if_needed() -> void:
	# Ce secours n'inscrit jamais de joueur lorsqu'un parent instancie le mini-jeu.
	if not create_test_player_when_running_directly:
		return
	if get_tree().current_scene != self or not PlayerRegistry.get_players().is_empty():
		return
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_RIGHT)


func _spawn_all_players() -> void:
	var players := PlayerRegistry.get_players()
	if players.is_empty():
		push_warning("ProjectileSurvival démarre sans joueur inscrit.")
		return

	# Un petit cercle évite les superpositions quel que soit le nombre final de joueurs.
	var arena_center := _arena_rect.get_center()
	var spawn_radius := minf(58.0, 18.0 * float(players.size()))
	for player_index in players.size():
		var player: LocalPlayer = players[player_index]
		var spawn_position := arena_center
		if players.size() > 1:
			var spawn_angle := -PI * 0.5 + TAU * float(player_index) / float(players.size())
			spawn_position += Vector2.from_angle(spawn_angle) * spawn_radius

		var player_star: SurvivalStar = SURVIVAL_STAR_SCENE.instantiate()
		_player_stars[player.id] = player_star
		player_container.add_child(player_star)
		player_star.setup(player, spawn_position, _arena_rect)
		player_star.eliminated.connect(_on_player_eliminated)


func _layout_arena() -> void:
	# La marge commune garde les acteurs et les avertissements loin des bords de fenêtre.
	var viewport_size := get_viewport_rect().size
	var safe_margin := minf(arena_margin, minf(viewport_size.x, viewport_size.y) * 0.2)
	_arena_rect = Rect2(
		Vector2(safe_margin, safe_margin),
		viewport_size - Vector2.ONE * safe_margin * 2.0,
	)

	# La bordure est une ligne fermée adaptée à toutes les tailles de fenêtre.
	var top_left := _arena_rect.position
	var top_right := Vector2(_arena_rect.end.x, _arena_rect.position.y)
	var bottom_right := _arena_rect.end
	var bottom_left := Vector2(_arena_rect.position.x, _arena_rect.end.y)
	arena_border.points = PackedVector2Array([
		top_left,
		top_right,
		bottom_right,
		bottom_left,
		top_left,
	])

	# Les éléments déjà présents reçoivent immédiatement les nouvelles limites.
	for player_star in _player_stars.values():
		player_star.set_arena_rect(_arena_rect)
	if asteroid_spawner != null:
		asteroid_spawner.set_arena_rect(_arena_rect)


func _on_player_eliminated(_player_star: SurvivalStar) -> void:
	# Une défaite n'est déclarée que lorsque la dernière étoile disparaît.
	_update_hud()
	if _get_survivor_count() == 0:
		_finish_round(false)


func _get_survivor_count() -> int:
	var survivor_count := 0
	for player_star in _player_stars.values():
		if player_star.is_alive():
			survivor_count += 1
	return survivor_count


func _update_hud() -> void:
	# Ce HUD local pourra être masqué lorsque le Backbone affichera son propre temps.
	var remaining_time := maxf(survival_duration - _elapsed_time, 0.0)
	time_label.text = "%02d" % ceili(remaining_time)
	remaining_label.text = "%d étoile(s)" % _get_survivor_count()


func _finish_round(won: bool) -> void:
	if _round_finished:
		return
	_round_finished = true

	# Tous les dangers et toutes les commandes sont figés avant d'annoncer le résultat.
	asteroid_spawner.stop()
	for asteroid in asteroid_container.get_children():
		asteroid.set_process(false)
		asteroid.set_physics_process(false)
	for player_star in _player_stars.values():
		player_star.set_input_enabled(false)

	# Les signaux constituent le futur point de raccordement au Backbone.
	result_panel.visible = true
	if won:
		result_label.text = "CONSTELLATION SAUVÉE"
		round_won.emit()
	else:
		result_label.text = "ÉTOILES ÉTEINTES"
		round_lost.emit()
