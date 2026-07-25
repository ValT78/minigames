class_name MinigameTransition
extends CanvasLayer

@onready var backdrop: Control = %Backdrop
@onready var objective_panel: PanelContainer = %ObjectivePanel
@onready var objective_label: Label = %ObjectiveLabel


func play(objective_text: String) -> void:
	# Une entrée brève rend le texte lisible presque pendant toute la seconde disponible.
	objective_label.text = objective_text
	objective_panel.modulate.a = 0.0
	objective_panel.scale = Vector2(0.92, 0.92)
	var entrance_tween := create_tween().set_parallel(true)
	entrance_tween.tween_property(objective_panel, "modulate:a", 1.0, 0.1)
	entrance_tween.tween_property(objective_panel, "scale", Vector2.ONE, 0.14).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	await entrance_tween.finished

	# Le temps central est réservé à la lecture, sans autre mouvement à l'écran.
	await get_tree().create_timer(0.58).timeout

	# Le jeu apparaît d'abord ; le texte reste opaque au-dessus jusqu'au dernier instant.
	var backdrop_tween := create_tween()
	backdrop_tween.tween_property(backdrop, "modulate:a", 0.0, 0.18).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	await backdrop_tween.finished

	# La disparition du texte clôt seule la transition.
	var text_tween := create_tween()
	text_tween.tween_property(objective_panel, "modulate:a", 0.0, 0.1)
	await text_tween.finished
	queue_free()
