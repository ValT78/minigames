extends Node2D

var player : LocalPlayer
@export var body : Node2D
@export var _distanceToCenter : float = 1
@onready var red_particle: GPUParticles2D = $Body/redParticle
@onready var musique_particule: GPUParticles2D = $Body/musiqueParticule
var leaveTimer : Timer

func setup(_player : LocalPlayer, postion : Vector2) :
	# Le menu recrée uniquement l'avatar visuel du joueur déjà inscrit.
	player = _player
	body.get_child(0).get_child(0).self_modulate = player.color
	global_position = postion
	leaveTimer = Timer.new()
	add_child(leaveTimer)
	leaveTimer.timeout.connect(leave)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not player : return
	body.position = body.position * 0.9 + player.input.direction * 0.1 * _distanceToCenter
	
	if player.input.action_1_just_pressed :
		red_particle.emitting = true
	if player.input.action_2_just_pressed :
		musique_particule.emitting = true
	
	if not player.input.direction.y == 1 :
		leaveTimer.stop()
	elif leaveTimer.is_stopped() :
		leaveTimer.start(1)

func leave() : 
	PlayerRegistry.leave_profile(player.profile_id)
	queue_free()
