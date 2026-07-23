extends Node2D

var timer : float = 9.999
var _isNumberChanging = false

@onready var time_label: Label = $MainScreenUI/PanelContainer/TimeLabel
@export var minigamesScene : Array[PackedScene]
@export var mainMenu : PackedScene
@onready var score_label: Label = $MainScreenUI/PanelContainer/ScoreLabel

var _actualMinigame : Node2D
var _score : int

func _ready() -> void:
	_actualMinigame = minigamesScene[randi_range(0,minigamesScene.size()-1)].instantiate()
	add_child(_actualMinigame)

func _process(delta: float) -> void:
	timer -= delta
	if timer < 0 : gameover()
	updateTimeDisplay()

func resetCountdown() -> void :
	timer = 9.999

func gameover() -> void :
	get_tree().change_scene_to_packed(mainMenu)

func updateScore() -> void : 
	_score += floori(timer)
	if _score < 10 : 
		flashUpdateLabel(score_label,"00" + str(_score))
	elif _score < 100:
		flashUpdateLabel(score_label,"0" + str(_score))
	else :
		flashUpdateLabel(score_label, str(min(999,_score)))
		
	

#region UI
func updateTimeDisplay() -> void :
	var next_text = str(floori(timer))
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
func minigameWon() -> void :
	updateScore()
	resetCountdown()
	_actualMinigame.queue_free()
	await get_tree().process_frame
	_actualMinigame = minigamesScene[randi_range(0,minigamesScene.size()-1)].instantiate()
	add_child(_actualMinigame)


func minigameLost() -> void :
	pass
#endregion
