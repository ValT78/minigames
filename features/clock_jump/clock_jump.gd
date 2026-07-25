class_name ClockJump
extends Node2D

signal round_won(winner_player_id: int)
signal round_lost

# Réglages courts adaptés au chronomètre actuel du Backbone.
@export_range(1, 10, 1) var creatures_to_win := 3
@export_range(5.0, 30.0, 1.0) var direct_test_duration := 10.0
@export_range(1, 6, 1) var maximum_active_bricks_per_player := 3
@export var create_test_players_when_running_directly := true

# Tous les éléments propres au jeu restent dans la feature.
const JUMPER_SCENE := preload("res://features/clock_jump/clock_jumper.tscn")
const CREATURE_SCENE := preload("res://features/clock_jump/clock_creature.tscn")
const PLATFORM_SCENE := preload("res://features/clock_jump/clock_jump_platform.tscn")

@onready var background: ColorRect = %Background
@onready var clock_decor: Node2D = %ClockDecor
@onready var platform_container: Node2D = %PlatformContainer
@onready var brick_container: Node2D = %BrickContainer
@onready var creature_container: Node2D = %CreatureContainer
@onready var player_container: Node2D = %PlayerContainer
@onready var score_row: HBoxContainer = %ScoreRow
@onready var local_time_label: Label = %LocalTimeLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var instruction_bar: HBoxContainer = %InstructionBar
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var hour_hand: Line2D = %HourHand
@onready var minute_hand: Line2D = %MinuteHand

# La manche conserve les acteurs, les scores et les briques par identifiant de joueur.
var _jumpers: Dictionary[int, ClockJumper] = {}
var _creature_scores: Dictionary[int, int] = {}
var _score_labels: Dictionary[int, Label] = {}
var _bricks_by_player_id: Dictionary = {}
var _platforms: Array[ClockJumpPlatform] = []
var _arena_rect := Rect2()
var _elapsed_time := 0.0
var _round_finished := false
var _uses_external_timer := false


func _ready() -> void:
	# Le GameManager ne pilote le temps que lorsque la scène est ajoutée au Backbone.
	_uses_external_timer = get_tree().current_scene != self
	_create_direct_test_players_if_needed()
	local_time_label.visible = not _uses_external_timer
	if _uses_external_timer:
		GameManager.round_timer_expired.connect(_on_round_timer_expired)

	# Le décor et le parcours existent avant les joueurs afin de garantir les positions de départ.
	_layout_arena()
	_create_course()
	_spawn_all_players()
	_update_hud()
	_play_intro()


func _exit_tree() -> void:
	# La connexion globale ne doit pas survivre au changement de mini-jeu.
	if GameManager.round_timer_expired.is_connected(_on_round_timer_expired):
		GameManager.round_timer_expired.disconnect(_on_round_timer_expired)


func _process(delta: float) -> void:
	if _round_finished:
		return

	# Le temps local sert uniquement lorsque cette scène est lancée directement.
	if not _uses_external_timer:
		_elapsed_time = minf(_elapsed_time + delta, direct_test_duration)
		if _elapsed_time >= direct_test_duration:
			_on_round_timer_expired()
	# Les aiguilles avancent doucement pour garder le décor vivant sans gêner la lecture.
	minute_hand.rotation += delta * 0.42
	hour_hand.rotation += delta * 0.07
	_update_hud()


func _create_direct_test_players_if_needed() -> void:
	# Trois profils permettent de tester immédiatement la course complète hors du Backbone.
	if not create_test_players_when_running_directly:
		return
	if get_tree().current_scene != self or not PlayerRegistry.get_players().is_empty():
		return
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_RIGHT)
	PlayerRegistry.join_profile(PlayerRegistry.MOUSE)


func _layout_arena() -> void:
	# Une marge haute laisse respirer le compteur global et encadre le cadran.
	var viewport_size := get_viewport_rect().size
	var horizontal_margin := minf(90.0, viewport_size.x * 0.06)
	var top_margin := minf(105.0, viewport_size.y * 0.11)
	var bottom_margin := minf(65.0, viewport_size.y * 0.07)
	_arena_rect = Rect2(
		Vector2(horizontal_margin, top_margin),
		viewport_size - Vector2(horizontal_margin * 2.0, top_margin + bottom_margin),
	)
	background.position = Vector2.ZERO
	background.size = viewport_size
	var clock_radius := minf(_arena_rect.size.x, _arena_rect.size.y) * 0.48
	clock_decor.position = _arena_rect.get_center()
	clock_decor.scale = Vector2.ONE * (clock_radius / 440.0)


func _create_course() -> void:
	# Le parcours fixe évite une génération procédurale inutile pour une manche de dix secondes.
	var platform_specs := [
		{"position": Vector2(0.50, 0.92), "width": 0.30},
		{"position": Vector2(0.27, 0.81), "width": 0.19},
		{"position": Vector2(0.54, 0.72), "width": 0.18},
		{"position": Vector2(0.79, 0.63), "width": 0.18},
		{"position": Vector2(0.49, 0.54), "width": 0.20},
		{"position": Vector2(0.20, 0.45), "width": 0.18},
		{"position": Vector2(0.48, 0.36), "width": 0.18},
		{"position": Vector2(0.76, 0.27), "width": 0.18},
		{"position": Vector2(0.43, 0.18), "width": 0.20},
		{"position": Vector2(0.68, 0.09), "width": 0.18},
	]

	# Chaque plateforme haute reçoit une créature, ce qui laisse assez de cibles à trois joueurs.
	for platform_index in platform_specs.size():
		var platform_spec: Dictionary = platform_specs[platform_index]
		var normalized_position: Vector2 = platform_spec["position"]
		var platform_size := Vector2(_arena_rect.size.x * float(platform_spec["width"]), 24.0)
		var platform_position := _arena_rect.position + Vector2(
			normalized_position.x * _arena_rect.size.x,
			normalized_position.y * _arena_rect.size.y,
		)

		var platform: ClockJumpPlatform = PLATFORM_SCENE.instantiate()
		platform_container.add_child(platform)
		platform.position = platform_position
		platform.setup(platform_size, true, Color("b98235"))
		_platforms.append(platform)
		if platform_index > 0:
			_spawn_creature_on_platform(platform, platform_size)


func _spawn_creature_on_platform(platform: ClockJumpPlatform, platform_size: Vector2) -> void:
	# La patrouille conserve une marge afin que la créature ne dépasse jamais du rouage.
	var creature: ClockCreature = CREATURE_SCENE.instantiate()
	creature_container.add_child(creature)
	var creature_position := platform.position - Vector2(0.0, platform_size.y * 0.5 + 21.0)
	var horizontal_margin := 28.0
	creature.setup(
		creature_position,
		platform.position.x - platform_size.x * 0.5 + horizontal_margin,
		platform.position.x + platform_size.x * 0.5 - horizontal_margin,
	)
	creature.squashed.connect(_on_creature_squashed)


func _spawn_all_players() -> void:
	var players := PlayerRegistry.get_players()
	if players.is_empty():
		push_warning("ClockJump démarre sans joueur inscrit.")
		return

	# Le large rouage inférieur répartit automatiquement un à trois ressorts.
	var starting_platform :ClockJumpPlatform = _platforms.front()
	var starting_width := starting_platform.platform_size.x
	for player_index in players.size():
		var player: LocalPlayer = players[player_index]
		var spawn_x := starting_platform.position.x + starting_width * (
			float(player_index + 1) / float(players.size() + 1) - 0.5
		)
		var spawn_position := Vector2(spawn_x, starting_platform.position.y - 60.0)

		var jumper: ClockJumper = JUMPER_SCENE.instantiate()
		player_container.add_child(jumper)
		jumper.setup(player, spawn_position, _arena_rect)
		jumper.brick_requested.connect(_on_brick_requested)
		_jumpers[player.id] = jumper
		_creature_scores[player.id] = 0
		_bricks_by_player_id[player.id] = []
		_create_score_label(player)


func _create_score_label(player: LocalPlayer) -> void:
	# Un petit compteur coloré suffit à montrer la course vers les trois créatures.
	var score_label := Label.new()
	score_label.custom_minimum_size = Vector2(190.0, 50.0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 27)
	score_label.add_theme_color_override("font_color", player.color.lightened(0.28))
	score_label.add_theme_color_override("font_shadow_color", Color("301d18"))
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	score_row.add_child(score_label)
	_score_labels[player.id] = score_label


func _on_brick_requested(jumper: ClockJumper, requested_position: Vector2) -> void:
	if _round_finished or jumper.player == null:
		return

	# Chaque joueur garde au maximum trois briques ; la plus ancienne disparaît ensuite.
	var player_id := jumper.player.id
	var player_bricks: Array = _bricks_by_player_id[player_id]
	var brick: ClockJumpPlatform = PLATFORM_SCENE.instantiate()
	brick_container.add_child(brick)
	brick.position = Vector2(
		clampf(requested_position.x, _arena_rect.position.x + 62.0, _arena_rect.end.x - 62.0),
		clampf(requested_position.y, _arena_rect.position.y + 20.0, _arena_rect.end.y - 20.0),
	)
	brick.setup(Vector2(124.0, 28.0), false, jumper.player.color.darkened(0.28))
	# La brique apparaît avec un petit impact élastique tout en gardant sa collision immédiate.
	brick.scale = Vector2(0.25, 0.25)
	var brick_tween := create_tween()
	brick_tween.tween_property(brick, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	player_bricks.append(brick)
	if player_bricks.size() > maximum_active_bricks_per_player:
		var oldest_brick: ClockJumpPlatform = player_bricks.pop_front()
		if is_instance_valid(oldest_brick):
			oldest_brick.queue_free()
	_bricks_by_player_id[player_id] = player_bricks


func _on_creature_squashed(player_id: int) -> void:
	if _round_finished or not _creature_scores.has(player_id):
		return

	# Le troisième écrasement verrouille immédiatement le résultat de la manche.
	_creature_scores[player_id] += 1
	_update_score_label(player_id)
	_pulse_score_label(player_id)
	if _creature_scores[player_id] >= creatures_to_win:
		_finish_round(player_id)


func _on_round_timer_expired() -> void:
	if _round_finished:
		return
	# Aucun classement secondaire : sans trois créatures, toute la manche est perdue.
	_finish_round(0)


func _finish_round(winner_player_id: int) -> void:
	if _round_finished:
		return
	_round_finished = true

	# Les acteurs sont figés avant de prévenir le Backbone pour éviter un résultat concurrent.
	for jumper in _jumpers.values():
		jumper.set_input_enabled(false)
	for creature in creature_container.get_children():
		if creature is ClockCreature:
			(creature as ClockCreature).set_movement_enabled(false)

	# Le lancement direct garde le panneau affiché ; le Backbone enchaîne sinon.
	result_panel.visible = true
	if winner_player_id > 0:
		var winner := _get_player_by_id(winner_player_id)
		result_label.text = "%s REMONTE L'HORLOGE !" % (
			winner.display_name.to_upper() if winner != null else "UN JOUEUR"
		)
		if winner != null:
			result_label.add_theme_color_override("font_color", winner.color.lightened(0.3))
		round_won.emit(winner_player_id)
		if _uses_external_timer:
			GameManager.minigameWon(winner_player_id)
	else:
		result_label.text = "LE TEMPS S'EST ARRÊTÉ"
		round_lost.emit()
		if _uses_external_timer:
			GameManager.minigameLost()


func _get_player_by_id(player_id: int) -> LocalPlayer:
	for player in PlayerRegistry.get_players():
		if player.id == player_id:
			return player
	return null


func _get_time_left() -> float:
	if _uses_external_timer:
		return GameManager.get_time_left()
	return maxf(direct_test_duration - _elapsed_time, 0.0)


func _update_hud() -> void:
	# Le compteur local disparaît automatiquement lorsque celui du Backbone est présent.
	local_time_label.text = "%02d" % ceili(_get_time_left())
	for player_id in _score_labels:
		_update_score_label(player_id)


func _update_score_label(player_id: int) -> void:
	if not _score_labels.has(player_id):
		return
	_score_labels[player_id].text = "J%d  %d/%d" % [
		player_id,
		_creature_scores.get(player_id, 0),
		creatures_to_win,
	]


func _play_intro() -> void:
	# L'objectif attire brièvement l'œil, puis laisse toute la place à la partie.
	objective_label.modulate.a = 0.0
	objective_label.scale = Vector2(0.7, 0.7)
	var objective_tween := create_tween()
	objective_tween.set_parallel(true)
	objective_tween.tween_property(objective_label, "modulate:a", 1.0, 0.18)
	objective_tween.tween_property(objective_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	objective_tween.chain().tween_property(objective_label, "modulate:a", 0.0, 0.3).set_delay(1.25)

	# Les quatre commandes montent ensemble depuis le bas et restent visibles pendant la manche.
	var instruction_position := instruction_bar.position
	instruction_bar.position.y += 18.0
	instruction_bar.modulate.a = 0.0
	var instruction_tween := create_tween()
	instruction_tween.set_parallel(true)
	instruction_tween.tween_property(instruction_bar, "position", instruction_position, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	instruction_tween.tween_property(instruction_bar, "modulate:a", 1.0, 0.25)


func _pulse_score_label(player_id: int) -> void:
	if not _score_labels.has(player_id):
		return
	# Le compteur du joueur concerné grossit brièvement à chaque créature écrasée.
	var score_label := _score_labels[player_id]
	score_label.pivot_offset = score_label.size * 0.5
	score_label.scale = Vector2(1.28, 1.28)
	var score_tween := create_tween()
	score_tween.tween_property(score_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
