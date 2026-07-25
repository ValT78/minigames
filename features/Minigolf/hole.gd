extends Area2D

func _on_body_entered(body: GolfBall) -> void:
	print(body)
	if not body._input : return
	print("player won ",body._input.id)
	GameManager.minigameWon(body._input.id)
