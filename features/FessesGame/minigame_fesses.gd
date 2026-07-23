extends Node2D

@onready var left_spawn: Marker2D = $LeftSpawn
@onready var right_spawn: Marker2D = $RightSpawn

enum SIDE {LEFT, RIGHT}
var current_pos : SIDE

func set_random_pos() -> void:
	current_pos = SIDE.LEFT if randf() < 0.5 else SIDE.RIGHT

@export var water_melon: PackedScene
@export var water_melon_to_crush := 50

var water_melon_crushed := 0
var current_water_melon: WaterMelon
@onready var bel_homme_aux_grosses_fesses: Node2D = $BelHommeAuxGrossesFesses

var players_score: Dictionary[LocalPlayer, int]

func _ready() -> void:
	for player in PlayerRegistry.get_players():
		players_score[player] = 0

func _physics_process(_delta: float) -> void:
	if is_instance_valid(current_water_melon):
		if current_water_melon.exploded:
			return
		
		for player in PlayerRegistry.get_players():
			bel_homme_aux_grosses_fesses.fesse_animation(player.input.direction)
			var input_score := check_input(player.input.direction)
			if input_score == 1:
				crushing_water_melon(player)
			if input_score == -1:
				players_score[player] -= 1
	else:
		set_random_pos()
		spawn_water_melon()
		
func check_input(input_direction : Vector2) -> int:
	# -1 si mauvais input, 1 si bon input, 0 si pas d'input
	if input_direction.x == 0:
		return 0
	
	return 1 if sign(input_direction.x) == sign(int(current_pos) - 0.5) else -1
		
func crushing_water_melon(player: LocalPlayer) -> void:
	current_water_melon.crush()
	players_score[player] += 1

func spawn_water_melon() -> void:
	current_water_melon = water_melon.instantiate()
	match current_pos:
		SIDE.LEFT:
			current_water_melon.global_position = left_spawn.global_position
		SIDE.RIGHT:
			current_water_melon.global_position = right_spawn.global_position
	
	add_child(current_water_melon)

	
	
