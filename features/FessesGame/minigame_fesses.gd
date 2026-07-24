extends Node2D

enum SIDE {LEFT, RIGHT}
var current_pos : SIDE

@onready var left_spawn: Marker2D = $LeftSpawn
@onready var right_spawn: Marker2D = $RightSpawn
@export var players_score_containers : Array[VBoxContainer]
@export var players_score_label : Array[Label]
@export var water_melon_scene: PackedScene
@export var water_melon_to_crush := 20

# Maybe have this global idk
@export var modulate_player_1 : Color
@export var modulate_player_2 : Color

@onready var bel_homme_aux_grosses_fesses: Node2D = $BelHommeAuxGrossesFesses
@onready var water_melon_splash: AudioStreamPlayer2D = $WaterMelonSplash
@onready var fail_sound: AudioStreamPlayer2D = $FailSound




# players_id => player_countdown
var players_countdown: Array[int]
var water_melon_crushed := 0
var current_water_melon: WaterMelon

func set_random_pos() -> void:
	current_pos = SIDE.LEFT if randf() < 0.5 else SIDE.RIGHT

func _create_direct_test_player_if_needed() -> void:
	if get_tree().current_scene != self or not PlayerRegistry.get_players().is_empty():
		return

	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_RIGHT)

func _ready() -> void:
	_create_direct_test_player_if_needed()
	GameManager.round_timer_expired.connect(_on_round_timer_expired)
			
	var players := PlayerRegistry.get_players()

	assert(len(players) <= 2)
	var i := 0
	for player in players:
		@warning_ignore("integer_division")
		players_countdown.append(water_melon_to_crush / len(players))
		players_score_label[player.id].text = str(players_countdown[player.id])
		players_score_containers[i].visible = true
		i += 1

func _physics_process(_delta: float) -> void:
	if is_instance_valid(current_water_melon):
		if current_water_melon.exploded:
			return
		
		for player in PlayerRegistry.get_players():
			bel_homme_aux_grosses_fesses.fesse_animation(player)
			var input_score := check_input(player)
			if input_score == 1:
				good_input(player)
			if input_score == -1:
				bad_input(player)
				
	else:
		set_random_pos()
		spawn_water_melon()
		
func _on_round_timer_expired() :
	# ton code cool ou rien si tu veux rien
	GameManager.minigameLost()
	
const SIDE_SIGN = {SIDE.LEFT: 1, SIDE.RIGHT: -1}
func check_input(player: LocalPlayer) -> int:
	var dir = SIDE_SIGN.get(current_pos, 0)
	if player.input.action_1_just_pressed: return dir
	if player.input.action_2_just_pressed: return -dir
	return 0

func bad_input(player: LocalPlayer) -> void:
	players_countdown[player.id] += 2 # punition
	players_score_label[player.id].text = str(players_countdown[player.id])
	fail_sound.bus = "Player"+str(player.id)
	fail_sound.play()

func good_input(player: LocalPlayer) -> void:
	players_countdown[player.id] -= 1
	players_score_label[player.id].text = str(players_countdown[player.id])
	if players_countdown[player.id] <= 0:
		print("Win of player :", player)
		GameManager.minigameWon(player.id)
			
	players_score_label[player.id].text = str(players_countdown[player.id])
	water_melon_splash.bus = "Player"+str(player.id)
	water_melon_splash.play()
	
	current_water_melon.crush(player)

func spawn_water_melon() -> void:
	current_water_melon = water_melon_scene.instantiate()
	current_water_melon.big_ass_man = bel_homme_aux_grosses_fesses
	match current_pos:
		SIDE.LEFT:
			current_water_melon.global_position = left_spawn.global_position
		SIDE.RIGHT:
			current_water_melon.global_position = right_spawn.global_position
	
	add_child(current_water_melon)
