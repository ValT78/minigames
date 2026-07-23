class_name DolphinRingRace
extends Node2D

signal round_won(winner_player_id: int)
signal round_lost

# Réglages de manche conçus pour le timer actuel de dix secondes.
@export_range(2, 8, 1) var ring_count := 3
@export_range(0.5, 5.0, 0.1) var ring_reveal_interval := 3
@export_range(5.0, 30.0, 1.0) var direct_test_duration := 10.0
@export_range(50.0, 220.0, 1.0) var arena_margin := 105.0
@export var create_test_players_when_running_directly := true

# Toutes les scènes de la feature restent regroupées dans son dossier.
const DOLPHIN_SCENE := preload("res://features/dolphin_ring_race/dolphin_runner.tscn")
const ROUTE_RING_SCENE := preload("res://features/dolphin_ring_race/route_ring.tscn")
const JELLYFISH_SCENE := preload("res://features/dolphin_ring_race/bump_jellyfish.tscn")

@onready var background: ColorRect = %Background
@onready var arena_border: Line2D = %ArenaBorder
@onready var ring_container: Node2D = %RingContainer
@onready var jellyfish_container: Node2D = %JellyfishContainer
@onready var player_container: Node2D = %PlayerContainer
@onready var local_time_label: Label = %LocalTimeLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel

# La scène garde ses acteurs et la progression indépendante de chaque joueur.
var _dolphins: Dictionary[int, DolphinRunner] = {}
var _next_ring_by_player_id: Dictionary[int, int] = {}
var _route_rings: Array[RouteRing] = []
var _ring_positions: Array[Vector2] = []
var _arena_rect := Rect2()
var _round_elapsed := 0.0
var _next_ring_to_reveal := 0
var _round_finished := false
var _uses_external_timer := false


func _ready() -> void:
	# Le GameManager pilote le timer uniquement lorsque cette scène est ajoutée au Backbone.
	_uses_external_timer = get_tree().current_scene != self
	_create_direct_test_players_if_needed()
	local_time_label.visible = not _uses_external_timer
	if _uses_external_timer:
		GameManager.round_timer_expired.connect(_on_round_timer_expired)
	get_viewport().size_changed.connect(_layout_arena)

	# L'arène et le parcours existent avant les acteurs pour garantir des spawns valides.
	_layout_arena()
	_create_route()
	_spawn_all_players()
	_reveal_due_rings()
	_update_local_timer()


func _exit_tree() -> void:
	# Les connexions globales ne doivent pas survivre au changement de mini-jeu.
	if get_viewport().size_changed.is_connected(_layout_arena):
		get_viewport().size_changed.disconnect(_layout_arena)
	if GameManager.round_timer_expired.is_connected(_on_round_timer_expired):
		GameManager.round_timer_expired.disconnect(_on_round_timer_expired)


func _process(delta: float) -> void:
	if _round_finished:
		return

	# Le temps local révèle les cerceaux un par un
	_round_elapsed += delta
	_reveal_due_rings()
	_update_local_timer()
	if not _uses_external_timer and _round_elapsed >= direct_test_duration:
		_on_round_timer_expired()


func _create_direct_test_players_if_needed() -> void:
	# Le lancement direct reste testable sans altérer une partie intégrée.
	if not create_test_players_when_running_directly:
		return
	if get_tree().current_scene != self or not PlayerRegistry.get_players().is_empty():
		return
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_RIGHT)
	PlayerRegistry.join_profile(PlayerRegistry.MOUSE)


func _create_route() -> void:
	_ring_positions = _generate_ring_positions()
	for ring_index in ring_count:
		var route_ring: RouteRing = ROUTE_RING_SCENE.instantiate()
		_route_rings.append(route_ring)
		ring_container.add_child(route_ring)
		route_ring.setup(ring_index, _ring_positions[ring_index])
		route_ring.dolphin_entered.connect(_on_dolphin_entered_ring)


func _generate_ring_positions() -> Array[Vector2]:
	# Les candidats longent les bords tout en évitant le HUD placé en haut à gauche.
	var left := _arena_rect.position.x
	var right := _arena_rect.end.x
	var top := _arena_rect.position.y
	var bottom := _arena_rect.end.y
	var width := _arena_rect.size.x
	var height := _arena_rect.size.y
	var candidates: Array[Vector2] = [
		Vector2(left + width * 0.38, top),
		Vector2(left + width * 0.66, top),
		Vector2(left + width * 0.88, top),
		Vector2(right, top + height * 0.22),
		Vector2(right, top + height * 0.5),
		Vector2(right, top + height * 0.8),
		Vector2(left + width * 0.82, bottom),
		Vector2(left + width * 0.53, bottom),
		Vector2(left + width * 0.24, bottom),
		Vector2(left, top + height * 0.78),
		Vector2(left, top + height * 0.48),
		Vector2(left, top + height * 0.25),
	]

	# Chaque nouveau point est le candidat restant le plus éloigné du précédent.
	var selected_positions: Array[Vector2] = []
	var first_candidate_index := randi_range(0, candidates.size() - 1)
	selected_positions.append(candidates.pop_at(first_candidate_index))
	while selected_positions.size() < ring_count:
		var previous_position: Vector2 = selected_positions.back()
		var farthest_candidate_index := 0
		var farthest_distance := -1.0
		for candidate_index in candidates.size():
			var candidate_distance: float = previous_position.distance_squared_to(
				candidates[candidate_index]
			)
			if candidate_distance > farthest_distance:
				farthest_distance = candidate_distance
				farthest_candidate_index = candidate_index
		selected_positions.append(candidates.pop_at(farthest_candidate_index))
	return selected_positions


func _spawn_all_players() -> void:
	var players := PlayerRegistry.get_players()
	if players.is_empty():
		push_warning("DolphinRingRace démarre sans joueur inscrit.")
		return

	# Une petite formation circulaire sépare équitablement tous les départs.
	var arena_center := _arena_rect.get_center()
	var spawn_radius := 48.0 if players.size() > 1 else 0.0
	for player_index in players.size():
		var player: LocalPlayer = players[player_index]
		var spawn_position := arena_center
		if players.size() > 1:
			var spawn_angle := TAU * float(player_index) / float(players.size())
			spawn_position += Vector2.from_angle(spawn_angle) * spawn_radius

		var dolphin: DolphinRunner = DOLPHIN_SCENE.instantiate()
		_dolphins[player.id] = dolphin
		_next_ring_by_player_id[player.id] = 0
		player_container.add_child(dolphin)
		dolphin.setup(player, spawn_position, _arena_rect)
		dolphin.update_progress(0, ring_count)
		dolphin.jellyfish_requested.connect(_on_jellyfish_requested)


func _reveal_due_rings() -> void:
	# Le premier cerceau apparaît immédiatement, puis un nouveau toutes les deux secondes.
	while (
		_next_ring_to_reveal < _route_rings.size()
		and _round_elapsed >= float(_next_ring_to_reveal) * ring_reveal_interval
	):
		_route_rings[_next_ring_to_reveal].reveal()
		_next_ring_to_reveal += 1


func _on_dolphin_entered_ring(route_index: int, dolphin: DolphinRunner) -> void:
	if _round_finished or dolphin.player == null:
		return
	var player_id := dolphin.player.id
	if not _next_ring_by_player_id.has(player_id):
		return
	if _next_ring_by_player_id[player_id] != route_index:
		return

	# Seul le prochain cerceau attendu fait progresser ce joueur.
	_next_ring_by_player_id[player_id] += 1
	var completed_ring_count: int = _next_ring_by_player_id[player_id]
	dolphin.update_progress(completed_ring_count, ring_count)
	_route_rings[route_index].flash(dolphin.player.color)
	if completed_ring_count >= ring_count:
		_finish_round(dolphin)


func _on_jellyfish_requested(dolphin: DolphinRunner, spawn_position: Vector2) -> void:
	if _round_finished or dolphin.player == null:
		return
	# Le contrôleur place les pièges dans un conteneur commun facile à nettoyer.
	var jellyfish: BumpJellyfish = JELLYFISH_SCENE.instantiate()
	jellyfish_container.add_child(jellyfish)
	jellyfish.setup(dolphin.player.id, spawn_position, dolphin.player.color)


func _on_round_timer_expired() -> void:
	if _round_finished:
		return
	_finish_round(null)


func _finish_round(winner: DolphinRunner) -> void:
	if _round_finished:
		return
	_round_finished = true

	# Le verrou commun empêche deux validations pendant le même tick physique.
	for dolphin in _dolphins.values():
		dolphin.set_input_enabled(false)
	for jellyfish in jellyfish_container.get_children():
		jellyfish.queue_free()

	# En test direct le résultat reste affiché, en partie le Backbone enchaîne les scènes.
	result_panel.visible = true
	if winner != null and winner.player != null:
		result_label.text = "%s GAGNE LA COURSE !" % winner.player.display_name.to_upper()
		result_label.modulate = winner.player.color.lightened(0.3)
		round_won.emit(winner.player.id)
		if _uses_external_timer:
			GameManager.minigameWon(winner.player.id)
	else:
		result_label.text = "LA MER SE REFERME…"
		round_lost.emit()
		if _uses_external_timer:
			GameManager.minigameLost()


func _layout_arena() -> void:
	# Une marge adaptable conserve les cerceaux et dauphins dans la fenêtre.
	var viewport_size := get_viewport_rect().size
	var safe_margin := minf(arena_margin, minf(viewport_size.x, viewport_size.y) * 0.18)
	_arena_rect = Rect2(
		Vector2(safe_margin, safe_margin),
		viewport_size - Vector2.ONE * safe_margin * 2.0
	)
	background.size = viewport_size

	# La bordure matérialise la zone où les dauphins sont contenus.
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

	# Les acteurs suivent un redimensionnement, le parcours reste fixe pendant la manche.
	for dolphin in _dolphins.values():
		dolphin.set_arena_rect(_arena_rect)


func _update_local_timer() -> void:
	# Ce compteur est caché quand le HUD global du Backbone est présent.
	var time_left := maxf(direct_test_duration - _round_elapsed, 0.0)
	local_time_label.text = "%02d" % ceili(time_left)
