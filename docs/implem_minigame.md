pour que le jeu marche avec le système de minijeu il faut 3 choses :
	
	- que le jeu se lance directement au lancement de la scéne
- connecter le signal de fin de jeu et connecter genre : 
		```gdscript
		func _ready() :
			GameManager.round_timer_expired.connect(_on_round_timer_expired)
			
		func_ _on_round_timer_expired() :
			# ton code cool ou rien si tu veux rien
			GameManager.minigameLost()
		```
