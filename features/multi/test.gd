extends SceneTree

# Le test accumule les erreurs pour afficher tous les comportements cassés en une fois.
var _failures := 0


func _init() -> void:
	# Instancie le registre sans lancer le lobby afin de tester uniquement son API.
	var registry_script: Script = load("res://features/multi/player_registry.gd")
	var registry: Node = registry_script.new()
	root.add_child(registry)
	registry.set_joining_enabled(true)

	# Une touche ZQSD physique doit inscrire le profil clavier gauche.
	var join_left := InputEventKey.new()
	join_left.physical_keycode = KEY_W
	join_left.pressed = true
	registry._input(join_left)
	_check(registry.get_players().size() == 1, "Le clavier gauche rejoint")

	var left_player: LocalPlayer = registry.get_player_for_profile(&"keyboard_left")
	_check(left_player != null, "Le joueur clavier gauche existe")
	_check(not registry.join_profile(&"keyboard_left"), "Un profil ne rejoint pas deux fois")
	join_left.pressed = false
	registry._input(join_left)

	# Après relâchement de la touche de participation, D produit la droite seule.
	var move_right := InputEventKey.new()
	move_right.physical_keycode = KEY_D
	move_right.pressed = true
	registry._input(move_right)
	_check(left_player.input.movement == Vector2.RIGHT, "Le déplacement est normalisé")

	# Vérifie séparément l'impulsion initiale et l'état maintenu du saut.
	var jump := InputEventKey.new()
	jump.keycode = KEY_SHIFT
	jump.location = KEY_LOCATION_LEFT
	jump.pressed = true
	registry._input(jump)
	_check(left_player.input.jump_just_pressed, "Maj gauche déclenche le saut")
	_check(left_player.input.jump_pressed, "Le saut reste actif tant que Maj est maintenue")
	left_player.input._finish_physics_frame()
	_check(not left_player.input.jump_just_pressed, "L'impulsion ne dure qu'un tick")
	_check(left_player.input.jump_pressed, "L'état maintenu survit aux ticks")
	jump.pressed = false
	registry._input(jump)
	_check(not left_player.input.jump_pressed, "Relâcher Maj arrête le saut maintenu")

	# Le chevron physique doit déclencher le dash même lorsque Maj est enfoncée.
	var left_dash := InputEventKey.new()
	left_dash.physical_keycode = KEY_LESS
	left_dash.shift_pressed = true
	left_dash.pressed = true
	registry._input(left_dash)
	_check(left_player.input.dash_just_pressed, "< déclenche le dash avec Maj")
	left_player.input._finish_physics_frame()

	# Les flèches inscrivent le deuxième clavier avant de tester ses actions AZERTY.
	var join_right := InputEventKey.new()
	join_right.keycode = KEY_RIGHT
	join_right.pressed = true
	registry._input(join_right)
	var right_player: LocalPlayer = registry.get_player_for_profile(&"keyboard_right")
	_check(right_player != null, "Le clavier droit rejoint")

	# La touche physique « : / » maintient le saut, avec ou sans Maj.
	var right_jump := InputEventKey.new()
	right_jump.physical_keycode = KEY_PERIOD
	right_jump.shift_pressed = true
	right_jump.pressed = true
	registry._input(right_jump)
	_check(right_player.input.jump_pressed, "/ maintient le saut avec Maj")
	right_jump.shift_pressed = false
	right_jump.pressed = false
	registry._input(right_jump)
	_check(not right_player.input.jump_pressed, "Relâcher / arrête le saut")

	# La touche physique « ! » déclenche le dash indépendamment de Maj.
	var right_dash := InputEventKey.new()
	right_dash.physical_keycode = KEY_SLASH
	right_dash.shift_pressed = true
	right_dash.pressed = true
	registry._input(right_dash)
	_check(right_player.input.dash_just_pressed, "! déclenche le dash avec Maj")

	# Un clic central inscrit la souris, active le saut, mais aucun déplacement.
	var join_mouse := InputEventMouseButton.new()
	join_mouse.button_index = MOUSE_BUTTON_LEFT
	join_mouse.pressed = true
	join_mouse.position = Vector2(576.0, 324.0)
	registry._input(join_mouse)
	var mouse_player: LocalPlayer = registry.get_player_for_profile(&"mouse")
	_check(mouse_player != null, "La souris rejoint")
	_check(mouse_player.id == 3, "L'ordre de connexion détermine l'identifiant")
	_check(mouse_player.input.jump_just_pressed, "Le clic gauche déclenche le saut")
	_check(mouse_player.input.jump_pressed, "Le clic gauche peut être maintenu")
	_check(mouse_player.input.movement == Vector2.ZERO, "La souris au centre ne bouge pas")

	# Le bord droit active X, tandis qu'un coin active simultanément X et Y.
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = Vector2(1152.0, 324.0)
	registry._input(mouse_motion)
	_check(mouse_player.input.movement == Vector2.RIGHT, "Le bord droit active la droite")
	mouse_motion.position = Vector2.ZERO
	registry._input(mouse_motion)
	_check(
		mouse_player.input.movement.x < 0.0 and mouse_player.input.movement.y < 0.0,
		"Un coin active deux directions",
	)
	join_mouse.pressed = false
	registry._input(join_mouse)
	_check(not mouse_player.input.jump_pressed, "Relâcher le clic arrête le saut maintenu")

	# Termine par les deux chemins de déconnexion disponibles dans le registre.
	_check(registry.leave_profile(&"mouse"), "Un profil peut quitter")
	_check(registry.get_players().size() == 2, "Le joueur est retiré")
	registry.clear_players()
	_check(registry.get_players().is_empty(), "Le registre peut être vidé")
	registry.free()

	if _failures == 0:
		print("Multi local smoke test: OK")
	quit(_failures)


func _check(condition: bool, message: String) -> void:
	# Contrairement à assert(), cette fonction laisse les vérifications suivantes tourner.
	if condition:
		return
	_failures += 1
	push_error("ÉCHEC: %s" % message)
