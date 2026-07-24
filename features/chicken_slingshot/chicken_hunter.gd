class_name ChickenHunter
extends Node2D

signal projectile_requested(
	player_id: int,
	spawn_position: Vector2,
	travel_direction: Vector2,
	charge_ratio: float,
	is_arrow: bool,
)

# La charge minimale autorise le tir ; la charge maximale fixe sa portée finale.
@export var movement_speed := 550.0
@export var maximum_aim_angle_degrees := 25.0
@export var minimum_charge_duration := 0.2
@export var maximum_charge_duration := 0.5
@export var shot_cooldown := 0.6
@export var body_radius := 30.0

@onready var hunter_visual: Node2D = %HunterVisual
@onready var body: Polygon2D = %Body
@onready var hat: Polygon2D = %Hat
@onready var weapon: Node2D = %Weapon
@onready var projectile_origin: Marker2D = %ProjectileOrigin
@onready var charge_bar: ProgressBar = %ChargeBar
@onready var arrow_badge: Label = %ArrowBadge
@onready var player_label: Label = %PlayerLabel

# Les états de charge restent locaux au tireur et indépendants des touches physiques.
var player: LocalPlayer
var _minimum_y := 0.0
var _maximum_y := 1080.0
var _charge_time := 0.0
var _cooldown_left := 0.0
var _is_charging := false
var _arrow_available := false
var _input_enabled := true


func setup(assigned_player: LocalPlayer, spawn_position: Vector2, arena_rect: Rect2) -> void:
	# Le joueur et sa couleur restent stables pendant toute la manche.
	player = assigned_player
	position = spawn_position
	set_vertical_bounds(arena_rect.position.y, arena_rect.end.y)
	_apply_player_style()


func _ready() -> void:
	# setup() peut être appelé juste avant ou juste après l'entrée dans l'arbre.
	charge_bar.min_value = 0.0
	charge_bar.max_value = maximum_charge_duration
	_apply_player_style()
	_update_action_visuals()


func _physics_process(delta: float) -> void:
	if player == null:
		return

	# Le déplacement vertical et l'angle utilisent uniquement la direction générique.
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var input_direction := player.input.direction if _input_enabled else Vector2.ZERO
	# Les deux axes ont des rôles distincts, donc une diagonale ne doit réduire ni l'un ni l'autre.
	var vertical_direction := signf(input_direction.y)
	var aim_direction := signf(input_direction.x)
	position.y += vertical_direction * movement_speed * delta
	position.y = clampf(position.y, _minimum_y + body_radius, _maximum_y - body_radius)
	weapon.rotation = deg_to_rad(maximum_aim_angle_degrees) * aim_direction

	# La flèche est instantanée et annule une éventuelle charge de caillou.
	if _input_enabled and _arrow_available and player.input.action_2_just_pressed:
		_cancel_charge()
		_fire_projectile(1.0, true)
		_arrow_available = false

	# Un caillou ne part qu'au relâchement après au moins une seconde maintenue.
	_update_charge(delta)
	_update_action_visuals()


func _update_charge(delta: float) -> void:
	if not _input_enabled:
		_cancel_charge()
		return

	if player.input.action_1_just_pressed and _cooldown_left <= 0.0:
		_is_charging = true
		_charge_time = 0.0

	if _is_charging and player.input.action_1_pressed:
		_charge_time = minf(_charge_time + delta, maximum_charge_duration)
	elif _is_charging:
		# Un relâchement trop rapide annule le tir sans déclencher le cooldown.
		if _charge_time >= minimum_charge_duration:
			var charge_ratio := inverse_lerp(
				minimum_charge_duration,
				maximum_charge_duration,
				_charge_time,
			)
			_fire_projectile(charge_ratio, false)
			_cooldown_left = shot_cooldown
		_cancel_charge()


func _fire_projectile(charge_ratio: float, is_arrow: bool) -> void:
	if player == null:
		return

	# Le canon local donne une origine et une direction cohérentes avec le visuel incliné.
	var travel_direction := Vector2.RIGHT.rotated(weapon.global_rotation)
	projectile_requested.emit(
		player.id,
		projectile_origin.global_position,
		travel_direction,
		clampf(charge_ratio, 0.0, 1.0),
		is_arrow,
	)


func grant_arrow() -> void:
	# Le badge reste visible jusqu'à l'utilisation de cette munition unique.
	if _input_enabled:
		_arrow_available = true
		_update_action_visuals()


func set_input_enabled(enabled: bool) -> void:
	# La fin de manche annule une charge pour empêcher un tir retardé.
	_input_enabled = enabled
	if not enabled:
		_cancel_charge()
	_update_action_visuals()


func set_vertical_bounds(minimum_y: float, maximum_y: float) -> void:
	_minimum_y = minimum_y
	_maximum_y = maximum_y
	position.y = clampf(position.y, _minimum_y + body_radius, _maximum_y - body_radius)


func _cancel_charge() -> void:
	_is_charging = false
	_charge_time = 0.0


func _update_action_visuals() -> void:
	if not is_node_ready():
		return

	# La barre passe au vert après la seconde obligatoire et continue vers la portée maximale.
	charge_bar.value = _charge_time
	charge_bar.visible = _is_charging
	charge_bar.modulate = (
		Color("8ff06a") if _charge_time >= minimum_charge_duration else Color("ffe072")
	)
	arrow_badge.visible = _arrow_available
	if _arrow_available:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.08
		arrow_badge.scale = Vector2.ONE * pulse


func _apply_player_style() -> void:
	if player == null or not is_node_ready():
		return

	# Deux nuances identifient le tireur sans modifier la lisibilité de la fronde.
	body.color = player.color.darkened(0.12)
	hat.color = player.color.lightened(0.2)
	player_label.text = "J%d" % player.id
	player_label.add_theme_color_override("font_color", player.color.lightened(0.35))
