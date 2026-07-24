extends Node2D
const PLAYER_TARGET = preload("uid://cl6jtpq3h2rtc")

var country : String = "France"
var countryList : Array[String] = ["France","Ukraine","Norway","Iceland","Lithuania","Greece","Morocco"]
var players : Array[Node2D] = []
@onready var country_indication: Label = $CountryIndication

func _create_direct_test_player_if_needed() -> void:
	if get_tree().current_scene != self or not PlayerRegistry.get_players().is_empty():
		return

	PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)
	#PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_RIGHT)

func _ready() -> void:
	country = countryList[randi_range(0,countryList.size()-1)]
	country_indication.text = "FIND\n" + country
	_create_direct_test_player_if_needed()
	GameManager.round_timer_expired.connect(_on_round_timer_expired)
			
	var playersInput := PlayerRegistry.get_players()

	assert(len(playersInput) <= 2)
	var i := 0
	for playerInput in playersInput:
		var player : Node2D = PLAYER_TARGET.instantiate()
		player.setup(playerInput)
		player.global_position = Vector2(1920,1080)/2
		add_child(player)
		pass

func _on_round_timer_expired() :
	# ton code cool ou rien si tu veux rien
	GameManager.minigameLost()
