extends SceneTree

# Le test accumule les erreurs pour afficher tous les comportements cassés en une fois.
var _failures := 0


func _init() -> void:
	# Le registre et le routeur sont instanciés séparément pour vérifier leur frontière.
	var registry_script: Script = load("res://features/multi/player_registry.gd")
	var registry: Node = registry_script.new()
	root.add_child(registry)

	var router_script: Script = load("res://features/multi/player_input_router.gd")
	var router: Node = router_script.new()
	router.set_registry(registry)
	root.add_child(router)
	router.set_joining_enabled(true)

	# Une touche ZQSD physique doit inscrire le profil clavier gauche.
	var join_left := InputEventKey.new()
	join_left.physical_keycode = KEY_W
	join_left.pressed = true
	router._input(join_left)
	_check(registry.get_players().size() == 1, "Le clavier gauche rejoint")

	var left_player: LocalPlayer = registry.get_player_for_profile(&"keyboard_left")
	_check(left_player != null, "Le joueur clavier gauche existe")
	_check(not registry.join_profile(&"keyboard_left"), "Un profil ne rejoint pas deux fois")
	join_left.pressed = false
	router._input(join_left)

	# Après relâchement de la participation, D produit la direction droite seule.
	var move_right := InputEventKey.new()
	move_right.physical_keycode = KEY_D
	move_right.pressed = true
	router._input(move_right)
	_check(left_player.input.direction == Vector2.RIGHT, "La direction est normalisée")

	# Action 1 expose séparément l'impulsion initiale et l'état maintenu.
	var action_1 := InputEventKey.new()
	action_1.keycode = KEY_SHIFT
	action_1.location = KEY_LOCATION_LEFT
	action_1.pressed = true
	router._input(action_1)
	_check(left_player.input.action_1_just_pressed, "Action 1 détecte le premier appui")
	_check(left_player.input.action_1_pressed, "Action 1 reste maintenue")
	left_player.input._finish_physics_frame()
	_check(not left_player.input.action_1_just_pressed, "L'impulsion ne dure qu'un tick")
	_check(left_player.input.action_1_pressed, "L'état maintenu survit aux ticks")
	action_1.pressed = false
	router._input(action_1)
	_check(not left_player.input.action_1_pressed, "Relâcher arrête Action 1")

	# Simule le cas Windows où la touche < reçoit un autre code physique ISO.
	var action_2 := InputEventKey.new()
	action_2.physical_keycode = KEY_BACKSLASH
	action_2.key_label = KEY_LESS
	action_2.unicode = ">".unicode_at(0)
	action_2.shift_pressed = true
	action_2.pressed = true
	router._input(action_2)
	_check(left_player.input.action_2_just_pressed, "Action 2 fonctionne avec Maj")
	_check(left_player.input.action_2_pressed, "Action 2 expose aussi un état maintenu")
	action_2.key_label = KEY_NONE
	action_2.unicode = 0
	action_2.pressed = false
	router._input(action_2)
	_check(not left_player.input.action_2_pressed, "Relâcher arrête Action 2")

	# Les flèches inscrivent le deuxième clavier avant de tester ses actions AZERTY.
	var join_right := InputEventKey.new()
	join_right.keycode = KEY_RIGHT
	join_right.pressed = true
	router._input(join_right)
	var right_player: LocalPlayer = registry.get_player_for_profile(&"keyboard_right")
	_check(right_player != null, "Le clavier droit rejoint")

	# La touche physique « : / » correspond à Action 1, avec ou sans Maj.
	var right_action_1 := InputEventKey.new()
	right_action_1.physical_keycode = KEY_PERIOD
	right_action_1.shift_pressed = true
	right_action_1.pressed = true
	router._input(right_action_1)
	_check(right_player.input.action_1_pressed, "Action 1 droite fonctionne avec Maj")
	right_action_1.shift_pressed = false
	right_action_1.pressed = false
	router._input(right_action_1)
	_check(not right_player.input.action_1_pressed, "Action 1 droite se relâche")

	# La touche physique « ! » correspond à Action 2 indépendamment de Maj.
	var right_action_2 := InputEventKey.new()
	right_action_2.physical_keycode = KEY_SLASH
	right_action_2.shift_pressed = true
	right_action_2.pressed = true
	router._input(right_action_2)
	_check(right_player.input.action_2_just_pressed, "Action 2 droite fonctionne avec Maj")

	# Un clic central inscrit la souris et déclenche Action 1 sans direction.
	var join_mouse := InputEventMouseButton.new()
	join_mouse.button_index = MOUSE_BUTTON_LEFT
	join_mouse.pressed = true
	join_mouse.position = Vector2(576.0, 324.0)
	router._input(join_mouse)
	var mouse_player: LocalPlayer = registry.get_player_for_profile(&"mouse")
	_check(mouse_player != null, "La souris rejoint")
	_check(mouse_player.id == 3, "L'ordre de connexion détermine l'identifiant")
	_check(mouse_player.input.action_1_pressed, "Le clic gauche maintient Action 1")
	_check(mouse_player.input.direction == Vector2.ZERO, "La souris au centre reste neutre")

	# Le bord droit active X, tandis qu'un coin active simultanément X et Y.
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = Vector2(1152.0, 324.0)
	router._input(mouse_motion)
	_check(mouse_player.input.direction == Vector2.RIGHT, "Le bord droit active la droite")
	mouse_motion.position = Vector2.ZERO
	router._input(mouse_motion)
	_check(
		mouse_player.input.direction.x < 0.0 and mouse_player.input.direction.y < 0.0,
		"Un coin active deux directions",
	)
	join_mouse.pressed = false
	router._input(join_mouse)
	_check(not mouse_player.input.action_1_pressed, "Relâcher le clic arrête Action 1")

	# Termine par les deux chemins de déconnexion disponibles dans le registre.
	_check(registry.leave_profile(&"mouse"), "Un profil peut quitter")
	_check(registry.get_players().size() == 2, "Le joueur est retiré")
	registry.clear_players()
	_check(registry.get_players().is_empty(), "Le registre peut être vidé")
	router.free()
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
