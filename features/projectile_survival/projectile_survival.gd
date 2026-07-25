class_name ProjectileSurvival
extends Node2D

signal round_won
signal round_lost

# Paramètres de manche modifiables sans toucher au générateur d'astéroïdes.
@export_multiline var minigame_objective := "COLLECT ENERGY FRAGMENTS !"
@export_range(5.0, 120.0, 1.0) var survival_duration := 20.0
@export_range(40.0, 180.0, 1.0) var arena_margin := 84.0
@export_range(1, 10, 1) var fragments_to_collect_per_player := 4
@export var create_test_player_when_running_directly := true

# Les acteurs restent entièrement contenus dans cette feature.
const SURVIVAL_STAR_SCENE := preload("res://features/projectile_survival/survival_star.tscn")
const ENERGY_FRAGMENT_SCENE := preload("res://features/projectile_survival/energy_fragment.tscn")

@onready var arena_border: Line2D = %ArenaBorder
@onready var asteroid_container: Node2D = %AsteroidContainer
@onready var fragment_container: Node2D = %FragmentContainer
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
var _uses_external_timer := false
var _collected_fragments_by_player: Dictionary[int, int] = {}


func _ready() -> void:
	# Le Backbone ajoute désormais les mini-jeux à la scène courante depuis son Autoload.
	_uses_external_timer = get_tree().current_scene != self
	_create_direct_test_player_if_needed()
	time_label.visible = not _uses_external_timer
	if _uses_external_timer:
		GameManager.round_timer_expired.connect(_on_round_timer_expired)
	get_viewport().size_changed.connect(_layout_arena)
	_layout_arena()
	_spawn_all_players()
	_spawn_initial_fragments()
	var round_duration := GameManager.MINI_GAMES_DURATION if _uses_external_timer else survival_duration
	asteroid_spawner.setup(_arena_rect, round_duration, asteroid_container)
	_update_hud()


func _exit_tree() -> void:
	# Évite de conserver une connexion vers une scène retirée entre deux mini-jeux.
	if get_viewport().size_changed.is_connected(_layout_arena):
		get_viewport().size_changed.disconnect(_layout_arena)
	if GameManager.round_timer_expired.is_connected(_on_round_timer_expired):
		GameManager.round_timer_expired.disconnect(_on_round_timer_expired)


func _process(delta: float) -> void:
	if _round_finished:
		return

	# Le temps local pilote le test direct, mais le Backbone décide en partie intégrée.
	_elapsed_time = minf(_elapsed_time + delta, survival_duration)
	_update_hud()
	if not _uses_external_timer and _elapsed_time >= survival_duration:
		_on_round_timer_expired()


func _on_round_timer_expired() -> void:
	# Le temps écoulé est toujours une défaite si le quota n'a pas été atteint.
	_finish_round(false, "FRAGMENTS INSUFFISANTS")


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
		_collected_fragments_by_player[player.id] = 0
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
	for energy_fragment in fragment_container.get_children():
		energy_fragment.position.x = clampf(
			energy_fragment.position.x,
			_arena_rect.position.x + 48.0,
			_arena_rect.end.x - 48.0,
		)
		energy_fragment.position.y = clampf(
			energy_fragment.position.y,
			_arena_rect.position.y + 48.0,
			_arena_rect.end.y - 48.0,
		)
	if asteroid_spawner != null:
		asteroid_spawner.set_arena_rect(_arena_rect)


func _on_player_eliminated(_player_star: SurvivalStar) -> void:
	# Une défaite n'est déclarée que lorsque la dernière étoile disparaît.
	_update_hud()
	if _get_survivor_count() == 0:
		_finish_round(false, "ÉTOILES ÉTEINTES")


func _spawn_initial_fragments() -> void:
	# Il reste toujours un fragment accessible par joueur pendant la manche.
	for fragment_index in _player_stars.size():
		_spawn_fragment(fragment_index)


func _spawn_fragment(spawn_index: int = 0) -> void:
	if _round_finished or _player_stars.is_empty():
		return
	var energy_fragment: EnergyFragment = ENERGY_FRAGMENT_SCENE.instantiate()
	fragment_container.add_child(energy_fragment)
	energy_fragment.position = _find_fragment_position(spawn_index)
	energy_fragment.collected.connect(_on_fragment_collected)


func _find_fragment_position(spawn_index: int) -> Vector2:
	# Quelques essais suffisent à éviter les joueurs et les autres fragments au départ.
	var fragment_margin := 48.0
	var available_rect := _arena_rect.grow(-fragment_margin)
	var fallback_angle := TAU * float(spawn_index) / float(maxi(_player_stars.size(), 1))
	var fallback_position := _arena_rect.get_center() + Vector2.from_angle(fallback_angle) * 120.0
	for _attempt_index in 12:
		var candidate := Vector2(
			randf_range(available_rect.position.x, available_rect.end.x),
			randf_range(available_rect.position.y, available_rect.end.y),
		)
		if _is_fragment_position_clear(candidate):
			return candidate
	return fallback_position


func _is_fragment_position_clear(candidate: Vector2) -> bool:
	for player_star in _player_stars.values():
		if candidate.distance_to(player_star.position) < 90.0:
			return false
	for energy_fragment in fragment_container.get_children():
		if candidate.distance_to(energy_fragment.position) < 90.0:
			return false
	return true


func _on_fragment_collected(energy_fragment: EnergyFragment, player_star: SurvivalStar) -> void:
	energy_fragment.queue_free()
	# Chaque collecte compte uniquement pour le joueur qui touche le fragment.
	var player_id := player_star.player.id
	_collected_fragments_by_player[player_id] += 1
	_update_hud()
	if _collected_fragments_by_player[player_id] >= fragments_to_collect_per_player:
		_finish_round(true, "%s GAGNE !" % player_star.player.display_name.to_upper(), player_id)
		return
	# Le remplacement différé empêche l'ancien fragment de gêner le nouveau placement.
	_spawn_fragment.call_deferred()


func _get_survivor_count() -> int:
	var survivor_count := 0
	for player_star in _player_stars.values():
		if player_star.is_alive():
			survivor_count += 1
	return survivor_count


func _update_hud() -> void:
	# Le temps local reste utile pour lancer et équilibrer cette scène directement.
	var remaining_time := maxf(survival_duration - _elapsed_time, 0.0)
	time_label.text = "%02d" % ceili(remaining_time)
	var player_scores: PackedStringArray = []
	for player in PlayerRegistry.get_players():
		var collected_fragments: int = _collected_fragments_by_player.get(player.id, 0)
		player_scores.append(
			"J%d %d/%d" % [player.id, collected_fragments, fragments_to_collect_per_player]
		)
	remaining_label.text = "  •  ".join(player_scores)


func _finish_round(won: bool, result_text: String, winner_player_id: int = -1) -> void:
	if _round_finished:
		return
	_round_finished = true

	# Tous les dangers et toutes les commandes sont figés avant d'annoncer le résultat.
	asteroid_spawner.stop()
	for asteroid in asteroid_container.get_children():
		asteroid.set_process(false)
		asteroid.set_physics_process(false)
	for energy_fragment in fragment_container.get_children():
		energy_fragment.set_process(false)
		energy_fragment.set_deferred("monitoring", false)
	for player_star in _player_stars.values():
		player_star.set_input_enabled(false)

	# Les signaux gardent la scène autonome, puis l'Autoload reçoit le résultat intégré.
	result_panel.visible = true
	result_label.text = result_text
	if won:
		round_won.emit()
		if _uses_external_timer:
			GameManager.minigameWon(winner_player_id)
	else:
		round_lost.emit()
		if _uses_external_timer:
			GameManager.minigameLost()
