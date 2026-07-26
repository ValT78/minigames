extends Control

@onready var explosion_artwork: Control = %ExplosionArtwork
@onready var bomb: TextureRect = %Bomb
@onready var flash: ColorRect = %Flash
@onready var game_over_label: Label = %GameOverLabel
@onready var final_score_label: Label = %FinalScoreLabel
@onready var scores: HBoxContainer = %Scores
@onready var first_score_card: PanelContainer = %FirstScoreCard
@onready var first_player_label: Label = %FirstPlayerLabel
@onready var first_score_label: Label = %FirstScoreLabel
@onready var second_score_card: PanelContainer = %SecondScoreCard
@onready var second_player_label: Label = %SecondPlayerLabel
@onready var second_score_label: Label = %SecondScoreLabel
@onready var quit_button: Button = %QuitButton

var _can_quit := false


func _ready() -> void:
	# Aucun nouveau joueur ne doit rejoindre pendant l'écran de résultat.
	PlayerInputRouter.set_joining_enabled(false)
	quit_button.pressed.connect(_on_quit_button_pressed)
	_display_final_scores()
	_play_intro_animation()


func _physics_process(_delta: float) -> void:
	if not _can_quit:
		return

	# L'action principale garde le bouton utilisable avec les contrôles de la partie.
	for player in PlayerRegistry.get_players():
		if player.input.action_1_just_pressed:
			_on_quit_button_pressed()
			return


func _unhandled_input(event: InputEvent) -> void:
	# Échap active directement l'unique bouton de cet écran clavier.
	if (
		_can_quit
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	):
		get_viewport().set_input_as_handled()
		_on_quit_button_pressed()


func _display_final_scores() -> void:
	var final_scores: Array[int] = GameManager.get_final_scores()
	var players: Array[LocalPlayer] = PlayerRegistry.get_players()
	var score_cards: Array[PanelContainer] = [first_score_card, second_score_card]
	var player_labels: Array[Label] = [first_player_label, second_player_label]
	var score_labels: Array[Label] = [first_score_label, second_score_label]

	# Chaque carte reprend le nom, la couleur et le score du joueur correspondant.
	for card_index in score_cards.size():
		var has_player := card_index < players.size()
		score_cards[card_index].visible = has_player
		if not has_player:
			continue
		var player := players[card_index]
		var player_score := final_scores[player.id] if player.id < final_scores.size() else 0
		player_labels[card_index].text = "PLAYER %d" % (card_index + 1)
		score_labels[card_index].text = "%03d" % mini(player_score, 999)
		score_labels[card_index].add_theme_color_override("font_color", player.color)

	# Le mode de test sans joueur garde malgré tout un résultat visible.
	if players.is_empty():
		first_score_card.visible = true
		first_player_label.text = "SCORE"
		first_score_label.text = "%03d" % mini(final_scores[0], 999)


func _play_intro_animation() -> void:
	# Le flash et l'explosion donnent un impact immédiat à la défaite.
	quit_button.disabled = true
	flash.modulate.a = 1.0
	explosion_artwork.scale = Vector2(0.1, 0.1)
	bomb.scale = Vector2(0.35, 0.35)
	bomb.rotation = -0.2
	game_over_label.modulate.a = 0.0
	final_score_label.modulate.a = 0.0
	scores.modulate.a = 0.0
	quit_button.modulate.a = 0.0

	var impact_tween := create_tween().set_parallel(true)
	impact_tween.tween_property(flash, "modulate:a", 0.0, 0.22)
	impact_tween.tween_property(explosion_artwork, "scale", Vector2.ONE, 0.42).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(bomb, "scale", Vector2.ONE, 0.48).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(bomb, "rotation", 0.0, 0.38).set_trans(Tween.TRANS_QUAD)
	await impact_tween.finished

	# Les informations arrivent ensuite pour ne pas concurrencer l'explosion.
	var content_tween := create_tween().set_parallel(true)
	content_tween.tween_property(game_over_label, "modulate:a", 1.0, 0.2)
	content_tween.tween_property(final_score_label, "modulate:a", 1.0, 0.2)
	content_tween.tween_property(scores, "modulate:a", 1.0, 0.2)
	content_tween.tween_property(quit_button, "modulate:a", 1.0, 0.2)
	await content_tween.finished
	_can_quit = true
	quit_button.disabled = false
	quit_button.grab_focus()


func _on_quit_button_pressed() -> void:
	if not _can_quit:
		return
	_can_quit = false
	quit_button.disabled = true
	GameManager.return_to_main_menu()
