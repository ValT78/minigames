class_name ClockJumper
extends CharacterBody2D

signal brick_requested(jumper: ClockJumper, brick_position: Vector2)

# Réglages principaux du rebond et des deux actions aériennes.
@export var horizontal_speed := 360.0
@export var horizontal_acceleration := 1900.0
@export var gravity_force := 900.0
@export var automatic_jump_speed := 650.0
@export var creature_bounce_speed := 760.0
@export var air_boost_impulse := 235.0
@export var maximum_upward_speed := 850.0
@export var fast_fall_speed := 760.0
@export var body_radius := 22.0

@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var player_label: Label = %PlayerLabel
@onready var spring_visual: Node2D = %SpringVisual
@onready var spring_line: Line2D = %SpringLine
@onready var top_plate: Polygon2D = %TopPlate
@onready var bottom_plate: Polygon2D = %BottomPlate
@onready var boost_glow: Polygon2D = %BoostGlow
@onready var action_feedback: Label = %ActionFeedback

# L'acteur conserve seulement son joueur et les états réinitialisés à chaque rebond.
var player: LocalPlayer
var _arena_rect := Rect2()
var _spawn_position := Vector2.ZERO
var _player_color := Color.WHITE
var _air_boost_available := true
var _brick_available := true
var _hit_lock_left := 0.0
var _input_enabled := true
var _fast_fall_was_active := false
var _feedback_origin := Vector2.ZERO
var _spring_tween: Tween
var _feedback_tween: Tween


func setup(assigned_player: LocalPlayer, spawn_position: Vector2, arena_rect: Rect2) -> void:
	# Le LocalPlayer fournit à la fois les commandes, le numéro et la couleur.
	player = assigned_player
	position = spawn_position
	_spawn_position = spawn_position
	_arena_rect = arena_rect
	_player_color = player.color
	_apply_player_style()


func _ready() -> void:
	# setup() peut être appelé juste avant ou juste après l'entrée dans l'arbre.
	_feedback_origin = action_feedback.position
	_apply_player_style()


func _physics_process(delta: float) -> void:
	if player == null:
		return

	# Les commandes restent brièvement verrouillées après un mauvais contact avec une créature.
	_hit_lock_left = maxf(_hit_lock_left - delta, 0.0)
	var input_direction := Vector2.ZERO
	if _input_enabled and _hit_lock_left <= 0.0:
		input_direction = player.input.direction
	velocity.x = move_toward(
		velocity.x,
		input_direction.x * horizontal_speed,
		horizontal_acceleration * delta,
	)

	# Bas accélère la chute ; les deux actions ne sont disponibles qu'une fois par rebond.
	if _input_enabled and _hit_lock_left <= 0.0:
		if input_direction.y > 0.5 and velocity.y < fast_fall_speed:
			velocity.y = fast_fall_speed
			if not _fast_fall_was_active:
				_play_action_feedback("BOP", Color("ffad52"))
				_play_spring_juice(Vector2(0.78, 1.3), 0.14)
		_fast_fall_was_active = input_direction.y > 0.5
		if player.input.action_1_just_pressed and _air_boost_available:
			# L'impulsion repart vers le haut même lorsqu'elle est déclenchée en pleine chute.
			velocity.y = maxf(minf(velocity.y, 0.0) - air_boost_impulse, -maximum_upward_speed)
			_air_boost_available = false
			_play_boost_juice()
		if player.input.action_2_just_pressed and _brick_available:
			_brick_available = false
			_play_action_feedback("BRICK", Color("ff737c"))
			_play_spring_juice(Vector2(1.18, 0.82), 0.16)
			var brick_position := global_position + Vector2(0.0, body_radius + 20.0)
			brick_requested.emit(self, brick_position)
	else:
		_fast_fall_was_active = false

	# La gravité précède le déplacement ; tout sol rencontré déclenche le prochain saut.
	velocity.y += gravity_force * delta
	move_and_slide()
	if is_on_floor():
		_start_automatic_jump(automatic_jump_speed)

	# Les bords horizontaux sont fermés et une chute complète replace le ressort au départ.
	position.x = clampf(position.x, _arena_rect.position.x + body_radius, _arena_rect.end.x - body_radius)
	if position.y > _arena_rect.end.y + 80.0:
		_respawn()


func can_squash_creature(creature_y: float) -> bool:
	# Il faut être en descente et encore au-dessus du centre de la créature.
	return velocity.y > 80.0 and global_position.y < creature_y - 4.0


func bounce_from_creature() -> void:
	# Un écrasement réussi offre un rebond plus haut et recharge les deux actions.
	_start_automatic_jump(creature_bounce_speed)
	_play_action_feedback("SPLOTCH !", Color("ffe06f"))


func hit_by_creature(creature_position: Vector2) -> void:
	if _hit_lock_left > 0.0:
		return

	# Un mauvais contact repousse le ressort et lui fait perdre un court instant de contrôle.
	var horizontal_push := signf(global_position.x - creature_position.x)
	if horizontal_push == 0.0:
		horizontal_push = 1.0
	velocity = Vector2(horizontal_push * 300.0, 230.0)
	_hit_lock_left = 0.3
	_play_action_feedback("OOF", Color("ff6b72"))
	_play_hit_juice(horizontal_push)


func set_input_enabled(enabled: bool) -> void:
	# La fin de manche coupe immédiatement toute nouvelle action.
	_input_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		set_physics_process(false)


func _start_automatic_jump(jump_speed: float) -> void:
	velocity.y = -jump_speed
	_air_boost_available = true
	_brick_available = true
	_play_spring_juice(Vector2(1.25, 0.72), 0.17)


func _respawn() -> void:
	# La chute pénalise la progression sans éliminer définitivement le joueur.
	position = _spawn_position
	velocity = Vector2(0.0, -automatic_jump_speed)
	_air_boost_available = true
	_brick_available = true


func _apply_player_style() -> void:
	if player == null or not is_node_ready():
		return
	player_label.text = "J%d" % player.id
	player_label.add_theme_color_override("font_color", player.color.lightened(0.35))
	# Les formes sont dessinées dans la scène et reçoivent seulement la couleur du joueur.
	spring_line.default_color = _player_color
	top_plate.color = _player_color.lightened(0.2)
	bottom_plate.color = _player_color.darkened(0.18)
	boost_glow.color = _player_color.lightened(0.35)


func _play_boost_juice() -> void:
	# Le halo et l'étirement vertical rendent l'impulsion évidente au premier regard.
	_play_action_feedback("BOOST", Color("72f5a6"))
	_play_spring_juice(Vector2(0.76, 1.38), 0.2)
	boost_glow.scale = Vector2(0.55, 0.55)
	boost_glow.modulate.a = 0.9
	var glow_tween := create_tween()
	glow_tween.set_parallel(true)
	glow_tween.tween_property(boost_glow, "scale", Vector2(1.45, 1.45), 0.24)
	glow_tween.tween_property(boost_glow, "modulate:a", 0.0, 0.24)


func _play_spring_juice(start_scale: Vector2, duration: float) -> void:
	if _spring_tween != null and _spring_tween.is_valid():
		_spring_tween.kill()
	# Le ressort se compresse ou s'étire, puis reprend rapidement sa silhouette normale.
	spring_visual.scale = start_scale
	_spring_tween = create_tween()
	_spring_tween.tween_property(spring_visual, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_action_feedback(feedback_text: String, feedback_color: Color) -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	# Un mot court monte au-dessus du joueur uniquement lors du déclenchement de l'action.
	action_feedback.text = feedback_text
	action_feedback.add_theme_color_override("font_color", feedback_color)
	action_feedback.position = _feedback_origin
	action_feedback.modulate.a = 1.0
	action_feedback.scale = Vector2(0.7, 0.7)
	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(action_feedback, "position:y", _feedback_origin.y - 22.0, 0.38)
	_feedback_tween.tween_property(action_feedback, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	_feedback_tween.tween_property(action_feedback, "modulate:a", 0.0, 0.38).set_delay(0.16)


func _play_hit_juice(horizontal_push: float) -> void:
	# Une courte inclinaison accompagne la poussée sans déplacer la collision.
	spring_visual.rotation = -horizontal_push * 0.28
	var hit_tween := create_tween()
	hit_tween.tween_property(spring_visual, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
