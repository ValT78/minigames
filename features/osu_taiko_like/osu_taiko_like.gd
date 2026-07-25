extends Node2D


@export var nb_to_crush := 15
@export_multiline var minigame_objective := "CRUSH WATERMELON!"
const WATERMELON_TAIKO = preload("uid://byywsxsgiaqac")
const GAME_LINE = preload("uid://gob0r73siqk7")
@onready var pos_multi_j_1: Marker2D = $PosMult_J1
@onready var pos_multi_j_2: Marker2D = $PosMult_J2
@onready var pos_single_j_1: Marker2D = $PosSingle_J1
@onready var water_melon_splash: AudioStreamPlayer2D = $WaterMelonSplash
@onready var fail_sound: AudioStreamPlayer2D = $FailSound

var players : Array[LocalPlayer]

@onready var tempo: Timer = $Tempo


var countdown_players : Array[int]

var game_lines : Array[TaikoGameLine]

func _on_round_timer_expired():
	GameManager.minigameLost()

# Init
func _create_direct_test_player_if_needed() -> void:
	if get_tree().current_scene != self or not PlayerRegistry.get_players().is_empty():
		return

	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_RIGHT)

func instantiate_line(player : LocalPlayer, line_gtrans: Transform2D):
		var game_line : TaikoGameLine = GAME_LINE.instantiate()
		game_line.global_transform = line_gtrans
		game_line.player = player
		if player.id == 0:
			game_line.press_line_area.area_entered.connect(_line_1_area_enter)
			game_line.press_line_area.area_exited.connect(_line_1_area_exit)
		else:
			game_line.press_line_area.area_entered.connect(_line_2_area_enter)
			game_line.press_line_area.area_exited.connect(_line_2_area_exit)
		game_lines.append(game_line)
		add_child(game_line)
		game_line.update_count_text(nb_to_crush)
		

func _ready() -> void:
	_create_direct_test_player_if_needed()
	players = PlayerRegistry.get_players()
	GameManager.round_timer_expired.connect(_on_round_timer_expired)

	if len(players) == 1:
		instantiate_line(players[0], pos_single_j_1.global_transform)
		countdown_players.append(nb_to_crush)
	else:
		instantiate_line(players[0], pos_multi_j_1.global_transform)
		instantiate_line(players[1], pos_multi_j_2.global_transform)
		countdown_players.append(nb_to_crush)
		countdown_players.append(nb_to_crush)

# Inputs

func _physics_process(_delta: float) -> void:
	var i := -1
	for player in players:
		i += 1
		var is_input_just_pressed = player.input.action_1_just_pressed || player.input.action_2_just_pressed || player.input.left_just_pressed || player.input.right_just_pressed || player.input.down_just_pressed || player.input.up_just_pressed
		if not is_input_just_pressed:
			continue

		var water_melon_destroyed = watermelon_destroyable_line1.pop_front() if i == 0 else watermelon_destroyable_line2.pop_front()
		game_lines[i].ass_crush_animation()
			
		# Bad input
		if not water_melon_destroyed:
			countdown_players[i] += 1 
			game_lines[i].update_count_text(countdown_players[i])
			fail_sound.play()
		else:
			# Good input
			water_melon_destroyed = water_melon_destroyed as WaterMelonTaiko
			countdown_players[i] -= 1
			
			if countdown_players[i] <= 0:
				GameManager.minigameWon(i)
			game_lines[i].update_count_text(countdown_players[i])
			water_melon_destroyed.crush(player)
			water_melon_splash.play()
			

var watermelon_destroyable_line1 : Array[WaterMelonTaiko]
var watermelon_destroyable_line2 : Array[WaterMelonTaiko]

func _line_1_area_enter(water_melon: WaterMelonTaiko):
	watermelon_destroyable_line1.append(water_melon)

func _line_1_area_exit(water_melon : WaterMelonTaiko):
	watermelon_destroyable_line1.erase(water_melon)

func _line_2_area_enter(water_melon: WaterMelonTaiko):
	watermelon_destroyable_line2.append(water_melon)

func _line_2_area_exit(water_melon : WaterMelonTaiko):
	watermelon_destroyable_line2.erase(water_melon)

# Watermelon spawn / Rythm

# Patterns with local tempoc count beetween 0 and 10 (1s)
var patterns = [[2], [2, 4], [2, 4, 6], [2, 6], [2, 6, 8], [6, 8], [1, 2, 3, 4, 5], [4, 5, 6], [1, 2, 8, 9]]
var current_pattern : Array

func spawn_watermelon(spawn_pos: Vector2):
	var new_water_melon : WaterMelonTaiko = WATERMELON_TAIKO.instantiate()
	new_water_melon.global_position = spawn_pos
	add_child(new_water_melon)

var global_tempo_count := 0
func _on_tempo_timeout() -> void:
	var local_tempo = global_tempo_count % 10
	if local_tempo == 0:
		current_pattern = patterns[randi() % patterns.size()]

	if local_tempo in current_pattern:
		if len(players) == 1:
			spawn_watermelon(pos_single_j_1.global_position + Vector2(1920.0, 0))
		else:
			spawn_watermelon(pos_multi_j_1.global_position + Vector2(1920.0, 0))
			spawn_watermelon(pos_multi_j_2.global_position + Vector2(1920.0, 0))
				
	global_tempo_count += 1
		
