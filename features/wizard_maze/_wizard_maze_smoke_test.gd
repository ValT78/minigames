extends Node

var _failure_count := 0


func _ready() -> void:
	# Le test attend que les Autoloads et la scène aient terminé leur initialisation.
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	await get_tree().process_frame
	var wizard_maze := get_parent() as WizardMaze
	_check(wizard_maze != null, "La scène principale se charge")
	if wizard_maze == null:
		get_tree().quit(1)
		return

	# Le lancement direct doit fournir deux chapeaux qui ne se collisionnent pas entre eux.
	_check(wizard_maze._wizard_hats.size() == 2, "Deux chapeaux de test apparaissent")
	var wizard_hats: Array[WizardHat] = []
	for wizard_hat in wizard_maze._wizard_hats.values():
		wizard_hats.append(wizard_hat)
	_check(wizard_hats[0].collision_layer == 0, "Les chapeaux n'ont pas de couche mutuelle")
	_check(wizard_hats[0].collision_mask == 1, "Les chapeaux détectent les murs")

	# La téléportation avance d'une cellule même lorsqu'un mur sépare les deux centres.
	var teleporter := wizard_hats[0]
	var cell_before := wizard_maze._maze_board.world_to_cell(teleporter.global_position)
	teleporter._last_pressed_direction = Vector2i.RIGHT
	teleporter._try_teleport()
	var cell_after := wizard_maze._maze_board.world_to_cell(teleporter.global_position)
	_check(cell_after == cell_before + Vector2i.RIGHT, "La téléportation traverse une cellule")

	# Le projectile ignore les murs et applique directement son état au rival touché.
	var target := wizard_hats[1]
	wizard_maze._on_spell_requested(teleporter, Vector2.RIGHT)
	var reverse_spell := wizard_maze.spell_container.get_child(0) as ReverseSpell
	reverse_spell.global_position = target.global_position
	reverse_spell._check_hat_hits()
	_check(target._reverse_time_left > 0.0, "Le sort inverse les commandes du rival")

	# Atteindre la rune de sortie termine immédiatement la manche avec le bon chapeau.
	teleporter.global_position = wizard_maze._maze_board.get_exit_position()
	teleporter._check_exit_reached()
	_check(wizard_maze._round_finished, "La rune de sortie termine la manche")

	# Un code de sortie non nul rend toute régression visible dans l'automatisation.
	if _failure_count == 0:
		print("WizardMaze smoke test: OK")
	get_tree().quit(1 if _failure_count > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failure_count += 1
	push_error("WizardMaze smoke test: " + message)
