extends Node2D

## Émis une seule fois lorsque le chronomètre de la manche atteint zéro.
signal round_timer_expired

const MINI_GAMES_DURATION = 14.999
const DEFAULT_MINIGAME_OBJECTIVE := "GET READY!"
const MINIGAME_TRANSITION_SCENE := preload(
	"res://features/minigame_transition/minigame_transition.tscn"
)

var _round_timer := Timer.new()
var isDebug : bool

var _isNumberChanging = false

var time_slider: HSlider
var time_label: Label
var minigamesScene : Array[PackedScene]
@onready var mainMenu : PackedScene = preload("uid://bjfhkvvyuqks4")
var score_container: VBoxContainer
var forceLoadScene : int = -1

var _actualMinigame : Node2D
var _score : Array[int] = [0,0]
var _is_transitioning := false

func _ready() -> void:
	# Le Timer natif garantit une seule notification lorsque le temps arrive à zéro.
	_round_timer.one_shot = true
	_round_timer.timeout.connect(_on_round_timer_timeout)
	add_child(_round_timer)
	get_tree().scene_changed.connect(_on_scene_changed)
	loadScenesFromFolder("res://minigames")
	if not OS.has_feature("editor") : forceLoadScene = -1
		
	
func _on_scene_changed() :
	isDebug = not get_tree().current_scene.name == "Main"
	if isDebug : return
	stop_round_timer()
	
	time_slider = $"../Main/MainScreenUI/TextureRect/HSlider"
	time_label = $"../Main/MainScreenUI/TimeLabel"
	score_container = $"../Main/MainScreenUI/Panel/MarginContainer/HBoxContainer/VBoxContainer"
	var playersInput := PlayerRegistry.get_players()
	
	assert(len(playersInput) <= 2)
	for playerInput in playersInput:
		var label : Label = score_container.get_child(playerInput.id)
		label.visible = true
		label.label_settings.font_color = playerInput.color
		label.get_child(0).label_settings.font_color = playerInput.color
		label.get_child(0).label_settings.font_color.a = 30/255
	
	startNewMinigame()
		

func _process(_delta: float) -> void:
	if isDebug : return
	if not is_instance_valid(time_label) : return
	updateTimeDisplay()

## Arrête le chronomètre sans émettre round_timer_expired.
func stop_round_timer() -> void:
	_round_timer.stop()

## Renvoie le nombre de secondes restantes
func get_time_left() -> float:
	return _round_timer.time_left

func _on_round_timer_timeout() -> void:
	round_timer_expired.emit()

func resetCountdown() -> void :
	_round_timer.start(MINI_GAMES_DURATION)

func gameover() -> void :
	_score = [0,0]
	stop_round_timer()
	get_tree().change_scene_to_packed(mainMenu)

func updateScore(index : int) -> void : 
	var score_label : Label = score_container.get_child(index)
	_score[index] += floori(get_time_left())
	if _score[index] < 10 : 
		flashUpdateLabel(score_label,"00" + str(_score[index]))
	elif _score[index] < 100:
		flashUpdateLabel(score_label,"0" + str(_score[index]))
	else :
		flashUpdateLabel(score_label, str(min(999,_score[index])))
		
func loadScenesFromFolder(folder_path: String):
	minigamesScene.clear()

	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("Impossible d'ouvrir : " + folder_path)
		return

	dir.list_dir_begin()

	while true:
		var file_name := dir.get_next()
		if file_name == "": break
		if dir.current_is_dir(): continue

		if file_name.ends_with(".tscn"):
			var scene := load(folder_path.path_join(file_name)) as PackedScene
			if scene:minigamesScene.append(scene)

	dir.list_dir_end()

func startNewMinigame() -> void:

	_is_transitioning = true
	stop_round_timer()
	var next_minigame_index := forceLoadScene
	if next_minigame_index == -1:
		next_minigame_index = randi_range(0, minigamesScene.size() - 1)
	var next_minigame_scene := minigamesScene[next_minigame_index]
	var next_minigame := next_minigame_scene.instantiate() as Node2D
	
	_actualMinigame = next_minigame
	_actualMinigame.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().current_scene.add_child(_actualMinigame)

	var objective_text := DEFAULT_MINIGAME_OBJECTIVE
	if "minigame_objective" in _actualMinigame:
		objective_text = str(_actualMinigame.get("minigame_objective"))
	var transition := MINIGAME_TRANSITION_SCENE.instantiate() as MinigameTransition
	get_tree().current_scene.add_child(transition)
	await transition.play(objective_text)

	# Pas de timer pendant la transition
	if not is_instance_valid(_actualMinigame):
		_is_transitioning = false
		return
	_actualMinigame.process_mode = Node.PROCESS_MODE_INHERIT
	resetCountdown()
	_is_transitioning = false

#region UI
func updateTimeDisplay() -> void :
	if get_time_left() > 0 :
		time_slider.value = 100 * get_time_left() / MINI_GAMES_DURATION
	var next_text = str(floori(get_time_left()))
	if next_text.length() < 2 : next_text = "0" + next_text
	if _isNumberChanging : return
	if time_label.text == next_text : return
	_isNumberChanging = true
	await flashUpdateLabel(time_label,next_text)
	_isNumberChanging = false

func flashUpdateLabel(label : Label, text : String) -> void :
	# Le changement de scène peut libérer le Label pendant l'animation asynchrone.
	if not is_instance_valid(label):
		return
	var tweenDown = create_tween()
	tweenDown.tween_property(label,"modulate:a",0,0.1)
	await tweenDown.finished
	if not is_instance_valid(label):
		return
	label.text = text
	var tweenUp = create_tween()
	tweenUp.tween_property(label,"modulate:a",1,0.1)
	await tweenUp.finished
#endregion

#region Game interface
func minigameWon(index : int = 0) -> void :
	if _is_transitioning:
		return
	_is_transitioning = true
	updateScore(index)
	stop_round_timer()
	_actualMinigame.queue_free()
	await get_tree().process_frame
	startNewMinigame()


func minigameLost() -> void :
	if _is_transitioning:
		return
	_is_transitioning = true
	stop_round_timer()
	call_deferred("gameover")
#endregion
