extends Control

var cursor_idle = preload("res://assets/menu/normal.png")
var cursor_click = preload("res://assets/menu/clicked.png")

@onready var bg_music = $bg_music

func _ready():
	Input.set_custom_mouse_cursor(cursor_idle)
	if bg_music:
		# 1. Set volume to silent (-80dB) BEFORE playing
		bg_music.volume_db = -80.0
		
		# 2. Start playing at the 10.0 second mark
		bg_music.play(13.0)
		
		# 3. Create a separate tween to fade the volume in softly
		var fade_tween = create_tween()
		fade_tween.tween_property(bg_music, "volume_db", 0.0, 2.0).set_trans(Tween.TRANS_SINE)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			Input.set_custom_mouse_cursor(cursor_click)
		else:
			Input.set_custom_mouse_cursor(cursor_idle)
