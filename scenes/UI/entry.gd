extends CanvasLayer

signal video_finished

@onready var container: Control = $MarginContainer
@onready var video_player: VideoStreamPlayer = $MarginContainer/VideoStreamPlayer
@onready var blocker: Control = $InputBlocker


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Tree pausieren → blockiert ALLES
	get_tree().paused = true

	_set_full_rect(blocker)
	_set_full_rect(container)
	_set_full_rect(video_player)

	blocker.mouse_filter = Control.MOUSE_FILTER_STOP

	if video_player != null:
		video_player.process_mode = Node.PROCESS_MODE_ALWAYS
		video_player.finished.connect(_on_video_finished)
		video_player.play()


func _input(event):
	# frisst wirklich jeden Input
	get_viewport().set_input_as_handled()


func _unhandled_input(event):
	get_viewport().set_input_as_handled()


func _set_full_rect(ctrl: Control) -> void:
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.offset_left = 0
	ctrl.offset_top = 0
	ctrl.offset_right = 0
	ctrl.offset_bottom = 0


func _on_video_finished():
	get_tree().paused = false
	video_finished.emit()
	queue_free()
