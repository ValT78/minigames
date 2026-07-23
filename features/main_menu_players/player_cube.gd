class_name PlayerCube
extends CharacterBody2D

# Paramètres de gameplay modifiables directement depuis l'inspecteur Godot.
@export var run_speed := 260.0
@export var jump_speed := 470.0
@export var gravity := 1350.0
@export var dash_speed := 720.0
@export var dash_duration := 0.14
@export var dash_cooldown := 0.35

# Éléments visuels personnalisés lors de l'association avec un joueur.
@onready var body: Polygon2D = $Body
@onready var player_label: Label = $PlayerLabel

# Joueur contrôlant ce cube et état interne de ses mouvements spéciaux.
var player: LocalPlayer
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _facing_direction := 1.0
var _spawn_position := Vector2.ZERO


## Associe le cube à un joueur et mémorise son point de réapparition.
func setup(assigned_player: LocalPlayer, spawn_position: Vector2) -> void:
	player = assigned_player
	_spawn_position = spawn_position
	position = spawn_position
	if is_node_ready():
		_apply_player_style()


func _ready() -> void:
	# setup() peut être appelé avant ou après _ready(), donc le style est vérifié ici aussi.
	_apply_player_style()


func _physics_process(delta: float) -> void:
	if player == null:
		return

	# Les deux compteurs empêchent un dash permanent ou répété trop rapidement.
	_dash_time_left = maxf(_dash_time_left - delta, 0.0)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)

	# La gravité ne s'applique que lorsque le cube n'est pas posé sur le sol.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Le mini-jeu lit uniquement l'API normalisée, jamais les touches physiques.
	var horizontal_input := player.input.direction.x
	if absf(horizontal_input) > 0.05:
		_facing_direction = signf(horizontal_input)

	# Maintenir l'action permet de ressauter dès que le cube retouche le sol.
	if player.input.action_1_pressed and is_on_floor():
		velocity.y = -jump_speed

	# Le dash conserve brièvement sa propre vitesse et sa dernière direction connue.
	if player.input.action_2_just_pressed and _dash_cooldown_left <= 0.0:
		var dash_direction := _facing_direction
		if absf(horizontal_input) > 0.05:
			dash_direction = signf(horizontal_input)
		velocity.x = dash_direction * dash_speed
		_dash_time_left = dash_duration
		_dash_cooldown_left = dash_cooldown

	# En dehors d'un dash, la vitesse horizontale suit directement la commande.
	if _dash_time_left <= 0.0:
		velocity.x = horizontal_input * run_speed

	# CharacterBody2D applique le mouvement puis résout les collisions avec le sol.
	move_and_slide()
	_keep_inside_viewport()


# Applique la couleur et le numéro provenant du LocalPlayer associé.
func _apply_player_style() -> void:
	if player == null or not is_node_ready():
		return
	body.color = player.color
	player_label.text = "J%d" % player.id


# Empêche de sortir horizontalement et replace le cube s'il tombe hors de la scène.
func _keep_inside_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position.x = clampf(position.x, 24.0, viewport_size.x - 24.0)
	if position.y > viewport_size.y + 120.0:
		position = _spawn_position
		velocity = Vector2.ZERO
