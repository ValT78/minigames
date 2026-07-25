extends Node2D

const HOLE_PLAYER = preload("uid://cnpsk7u6o6k8n")

@export_multiline var minigame_objective := "CATCH BALLS!"
var players : Array[Node2D] = []

func _create_direct_test_player_if_needed() -> void:
	if get_tree().current_scene != self or not PlayerRegistry.get_players().is_empty():
		return

	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)
	#PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_RIGHT)

func _ready() -> void:
	_create_direct_test_player_if_needed()
	GameManager.round_timer_expired.connect(_on_round_timer_expired)
			
	var playersInput := PlayerRegistry.get_players()

	assert(len(playersInput) <= 2)
	var i := 0
	for playerInput in playersInput:
		var player : Node2D = HOLE_PLAYER.instantiate()
		player.setup(playerInput)
		if playersInput.size() == 1 :
			player.global_position = Vector2(1920,1080)/2
		else :
			if playerInput.id == 1 :
				player.global_position = Vector2(1720,1080)/2
			else : 
				player.global_position = Vector2(2120,1080)/2
				
		add_child(player)
		pass

func _on_round_timer_expired() :
	GameManager.minigameLost()
