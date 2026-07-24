extends Node2D

const PLAYER = preload("uid://5cm10smsfx3p")
var players : Dictionary[int,Node2D]
var startTimer : Timer = Timer.new()
@onready var h_slider: HSlider = $TextureRect/HSlider
const MAIN = preload("uid://hfn6j6o6a0d0")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerRegistry.players_changed.connect(_sync_player)
	PlayerInputRouter.set_joining_enabled(true)
	_sync_player(PlayerRegistry.get_players())
	startTimer.timeout.connect(_launchGame)
	add_child(startTimer)
	

func _launchGame() :
	get_tree().change_scene_to_packed(MAIN)

func _process(delta: float) -> void:
	var isAllPlayerReady : bool = players.size() > 0
	for player in players.values() :
		if player.player == null : return
		isAllPlayerReady = isAllPlayerReady && (player.player.input.direction.y == -1.0)
	
	if not isAllPlayerReady : 
		startTimer.stop()
	elif startTimer.is_stopped():
		startTimer.start(3)
	
	h_slider.value = 100 if not isAllPlayerReady else 100 * startTimer.time_left /3.0

func _sync_player(playersInputs: Array[LocalPlayer]) -> void:
	var active_ids: Array[int] = []
	for playerInput in playersInputs:
		active_ids.append(playerInput.id)
		if not players.has(playerInput.id):
			var playerInstance: Node2D = PLAYER.instantiate()
			players[playerInput.id] = playerInstance
			print(playerInput.profile_name)
			match playerInput.profile_name :
				"Clavier gauche" : playerInstance.setup(playerInput, Vector2(700,800))
				"Clavier droit" : playerInstance.setup(playerInput, Vector2(1220,800))
				"Souris" : return
					
			
			add_child(playerInstance)

	for player_id in players.keys():
		if player_id not in active_ids:
			players[player_id].queue_free()
			players.erase(player_id)
		
