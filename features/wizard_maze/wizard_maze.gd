class_name WizardMaze
extends Node2D

signal round_won(winner_player_id: int)
signal round_lost

@export_multiline var minigame_objective := "ESCAPE THE WIZARD MAZE BEFORE THE OTHERS!"
@export_range(9, 31, 2) var maze_width := 21
@export_range(7, 19, 2) var maze_height := 11
@export_range(30, 140, 1) var target_path_length := 64
@export_range(5.0, 30.0, 1.0) var direct_test_duration := 15.0
@export var create_test_players_when_running_directly := true

@export_category("Maze layout")
@export var maze_position_offset := Vector2(0.0, -80.0)
@export_range(0.0, 600.0, 1.0) var maze_left_margin := 285.0
@export_range(0.0, 600.0, 1.0) var maze_top_margin := 205.0
@export_range(0.0, 600.0, 1.0) var maze_right_margin := 25.0
@export_range(0.0, 600.0, 1.0) var maze_bottom_margin := 150.0

# Tous les éléments propres au mini-jeu restent regroupés dans sa feature.
const MAZE_BOARD_SCENE := preload("res://features/wizard_maze/maze_board.tscn")
const WIZARD_HAT_SCENE := preload("res://features/wizard_maze/wizard_hat.tscn")
const REVERSE_SPELL_SCENE := preload("res://features/wizard_maze/reverse_spell.tscn")

@onready var background: ColorRect = %Background
@onready var board_container: Node2D = %BoardContainer
@onready var player_container: Node2D = %PlayerContainer
@onready var spell_container: Node2D = %SpellContainer
@onready var local_time_label: Label = %LocalTimeLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel

var _maze_board: WizardMazeBoard
var _wizard_hats: Dictionary[int, WizardHat] = {}
var _elapsed_time := 0.0
var _round_finished := false
var _uses_external_timer := false


func _ready() -> void:
	# Le GameManager pilote le temps uniquement quand il ajoute ce mini-jeu au Backbone.
	_uses_external_timer = get_tree().current_scene != self
	_create_direct_test_players_if_needed()
	local_time_label.visible = not _uses_external_timer
	if _uses_external_timer:
		GameManager.round_timer_expired.connect(_on_round_timer_expired)

	# Le labyrinthe et ses collisions doivent exister avant l'apparition des chapeaux.
	_layout_background()
	_create_maze()
	_spawn_all_wizard_hats()
	_update_local_hud()


func _exit_tree() -> void:
	# La connexion globale ne doit pas survivre au changement de mini-jeu.
	if GameManager.round_timer_expired.is_connected(_on_round_timer_expired):
		GameManager.round_timer_expired.disconnect(_on_round_timer_expired)


func _process(delta: float) -> void:
	if _round_finished:
		return

	# Le compteur local permet de tester la scène directement dans l'éditeur.
	if not _uses_external_timer:
		_elapsed_time = minf(_elapsed_time + delta, direct_test_duration)
		_update_local_hud()
		if _elapsed_time >= direct_test_duration:
			_on_round_timer_expired()


func _create_direct_test_players_if_needed() -> void:
	# Deux profils clavier reproduisent la partie intégrée sans toucher au lobby.
	if not create_test_players_when_running_directly:
		return
	if get_tree().current_scene != self or not PlayerRegistry.get_players().is_empty():
		return
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_RIGHT)


func _layout_background() -> void:
	# Le fond couvre la taille logique complète, y compris avec un viewport étiré.
	var viewport_size := get_viewport_rect().size
	background.position = Vector2.ZERO
	background.size = viewport_size


func _create_maze() -> void:
	# Le générateur favorise les virages tout en garantissant une route vers la sortie.
	var generator := WizardMazeGenerator.new()
	var maze_data := generator.generate(maze_width, maze_height, target_path_length)
	_maze_board = MAZE_BOARD_SCENE.instantiate()
	board_container.add_child(_maze_board)
	_maze_board.setup(maze_data, _get_available_maze_rect())


func _get_available_maze_rect() -> Rect2:
	# Les marges sont indépendantes afin de déplacer ou agrandir le plateau depuis l'inspecteur.
	var viewport_size := get_viewport_rect().size
	return _create_maze_rect_from_margins(
		viewport_size,
		maze_left_margin,
		maze_top_margin,
		maze_right_margin,
		maze_bottom_margin,
	)


func _create_maze_rect_from_margins(
	viewport_size: Vector2,
	left_margin: float,
	top_margin: float,
	right_margin: float,
	bottom_margin: float,
) -> Rect2:
	# Le décalage déplace le plateau sans obliger à équilibrer deux marges opposées.
	var maze_area_size := Vector2(
		maxf(viewport_size.x - left_margin - right_margin, 1.0),
		maxf(viewport_size.y - top_margin - bottom_margin, 1.0),
	)
	return Rect2(Vector2(left_margin, top_margin) + maze_position_offset, maze_area_size)


func _spawn_all_wizard_hats() -> void:
	var players := PlayerRegistry.get_players()
	if players.is_empty():
		push_warning("WizardMaze démarre sans joueur inscrit.")
		return

	# Les chapeaux partagent la même cellule équitable, mais restent lisibles grâce à un petit décalage.
	var start_position := _maze_board.cell_to_world_center(Vector2i(0, maze_height / 2))
	for player_index in players.size():
		var player: LocalPlayer = players[player_index]
		var vertical_offset := (float(player_index) - float(players.size() - 1) * 0.5) * 22.0
		var wizard_hat: WizardHat = WIZARD_HAT_SCENE.instantiate()
		player_container.add_child(wizard_hat)
		wizard_hat.setup(player, _maze_board, start_position + Vector2(0.0, vertical_offset))
		wizard_hat.spell_requested.connect(_on_spell_requested)
		wizard_hat.exit_reached.connect(_on_hat_reached_exit)
		_wizard_hats[player.id] = wizard_hat


func _on_spell_requested(caster: WizardHat, direction: Vector2) -> void:
	if _round_finished or caster.player == null:
		return

	# La liste très courte des cibles rend une détection manuelle plus simple qu'une couche physique.
	var spell_targets: Array[WizardHat] = []
	for wizard_hat in _wizard_hats.values():
		spell_targets.append(wizard_hat)
	var reverse_spell: ReverseSpell = REVERSE_SPELL_SCENE.instantiate()
	spell_container.add_child(reverse_spell)
	reverse_spell.global_position = caster.global_position + direction * 32.0
	reverse_spell.setup(
		caster.player.id,
		direction,
		caster.player.color.lightened(0.35),
		spell_targets,
		_maze_board.get_cell_size() * 9.0,
	)


func _on_hat_reached_exit(winner: WizardHat) -> void:
	if winner.player == null:
		return
	_finish_round(winner)


func _on_round_timer_expired() -> void:
	# Aucun chapeau au sceau lorsque le temps tombe à zéro signifie une défaite commune.
	_finish_round(null)


func _finish_round(winner: WizardHat) -> void:
	if _round_finished:
		return
	_round_finished = true

	# Le verrou commun empêche une seconde sortie ou un dernier sort pendant le même tick.
	for wizard_hat in _wizard_hats.values():
		wizard_hat.set_input_enabled(false)
	for reverse_spell in spell_container.get_children():
		reverse_spell.queue_free()
	result_panel.visible = true

	# Le Backbone reçoit l'identifiant stable qui correspond à son compteur de score.
	if winner != null and winner.player != null:
		result_label.text = "%s ESCAPE FROM LABYRINTH !" % winner.player.display_name.to_upper()
		result_label.modulate = winner.player.color.lightened(0.3)
		round_won.emit(winner.player.id)
		if _uses_external_timer:
			GameManager.minigameWon(winner.player.id)
	else:
		result_label.text = "THE LABYRINTH HOLDS THE HATS…"
		round_lost.emit()
		if _uses_external_timer:
			GameManager.minigameLost()


func _update_local_hud() -> void:
	# Ce compteur est masqué lorsque le HUD global est déjà présent.
	var time_left := maxf(direct_test_duration - _elapsed_time, 0.0)
	local_time_label.text = "%02d" % ceili(time_left)
