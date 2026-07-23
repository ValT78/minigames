extends Control

const TOTAL_TIME : float = 20.0
var time_left : float = TOTAL_TIME
var timer_paused : bool = false

@onready var progress_bar: ProgressBar = $ProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	progress_bar.max_value = TOTAL_TIME


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	process_timer(delta)

func process_timer(delta: float) -> void:
	if not(timer_paused):
		time_left -= delta
		progress_bar.value = time_left
	
	if time_left <= 0:
		
