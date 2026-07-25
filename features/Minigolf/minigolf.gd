extends Node2D

@export_multiline var minigame_objective := "BE THE FIRST TO SINK YOUR BALL!"
var players : Array[Node2D] = []
const GOLF_BALL = preload("uid://b2qxxe27cajph")

func _create_direct_test_player_if_needed() -> void:
	if get_tree().current_scene != self or not PlayerRegistry.get_players().is_empty():
		return

	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)
	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_RIGHT)

func _ready() -> void:
	_create_direct_test_player_if_needed()
	GameManager.round_timer_expired.connect(_on_round_timer_expired)
			
	var playersInput := PlayerRegistry.get_players()

	assert(len(playersInput) <= 2)
	var i := 0
	for playerInput in playersInput:
		var player : Node2D = GOLF_BALL.instantiate()
		player.setup(playerInput)
		match playerInput.id :
			0 : player.global_position = Vector2(1500,800)
			1 : player.global_position = Vector2(1600,800)
		
		add_child(player)
		pass

func _on_round_timer_expired() :
	GameManager.minigameLost()
