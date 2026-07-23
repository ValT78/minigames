extends Node2D

## Émis une seule fois lorsque le chronomètre de la manche atteint zéro.
signal round_timer_expired

const MINI_GAMES_DURATION = 9.999

var _round_timer := Timer.new()
var isDebug : bool

var _isNumberChanging = false

var time_slider: HSlider
var time_label: Label
@export var minigamesScene : Array[PackedScene]
@onready var mainMenu : PackedScene = preload("uid://bjfhkvvyuqks4")
var score_label: Label

var _actualMinigame : Node2D
var _score : int

func _ready() -> void:
	isDebug = not get_tree().current_scene.name == "Main"
	# Le Timer natif garantit une seule notification lorsque le temps arrive à zéro.
	_round_timer.one_shot = true
	_round_timer.timeout.connect(_on_round_timer_timeout)
	add_child(_round_timer)
	resetCountdown()
	
	if isDebug : return
	
	loadScenesFromFolder("res://minigames")
	time_slider = $"../Main/MainScreenUI/TextureRect/HSlider"
	time_label = $"../Main/MainScreenUI/TimeLabel"
	score_label = $"../Main/MainScreenUI/ScoreLabel"
	_actualMinigame = minigamesScene[randi_range(0,minigamesScene.size()-1)].instantiate()
	get_tree().current_scene.add_child(_actualMinigame)

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
	stop_round_timer()
	get_tree().change_scene_to_packed(mainMenu)

func updateScore(index : int) -> void : 
	_score += floori(get_time_left())
	if _score < 10 : 
		flashUpdateLabel(score_label,"00" + str(_score))
	elif _score < 100:
		flashUpdateLabel(score_label,"0" + str(_score))
	else :
		flashUpdateLabel(score_label, str(min(999,_score)))
		
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

#region UI
func updateTimeDisplay() -> void :
	if get_time_left() > 0 :
		time_slider.value = 100 * get_time_left() / MINI_GAMES_DURATION
	var next_text = str(floori(get_time_left()))
	if _isNumberChanging : return
	if time_label.text == next_text : return
	_isNumberChanging = true
	await flashUpdateLabel(time_label,next_text)
	_isNumberChanging = false

func flashUpdateLabel(label : Label, text : String) -> void :
	var tweenDown = create_tween()
	tweenDown.tween_property(time_label,"label_settings:font_color:a",0,0.1)
	await tweenDown.finished
	label.text = text
	var tweenUp = create_tween()
	tweenUp.tween_property(time_label,"label_settings:font_color:a",1,0.1)
	await tweenUp.finished
#endregion

#region Game interface
func minigameWon(index : int = 0) -> void :
	updateScore(index)
	resetCountdown()
	_actualMinigame.queue_free()
	await get_tree().process_frame
	_actualMinigame = minigamesScene[randi_range(0,minigamesScene.size()-1)].instantiate()
	get_tree().current_scene.add_child(_actualMinigame)


func minigameLost() -> void :
	gameover()
#endregion
