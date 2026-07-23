extends SceneTree


func _init() -> void:
	var registry_script: Script = load("res://features/multi/player_registry.gd")
	var registry: Node = registry_script.new()

	assert(registry.get_players().is_empty())
	assert(registry.join_profile(&"keyboard_left"))
	assert(not registry.join_profile(&"keyboard_left"))
	assert(registry.join_profile(&"mouse"))
	assert(registry.get_players().size() == 2)
	assert(registry.get_player_for_profile(&"mouse")["id"] == 2)

	registry.clear_players()
	assert(registry.get_players().is_empty())
	registry.free()

	print("Multi local smoke test: OK")
	quit()
