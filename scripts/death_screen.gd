extends Control

const START_SCENE := "res://scenes/UI/start-menu.tscn"

@onready var continue_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Button

func _ready() -> void:
	# Button verbinden
	if continue_button:
		continue_button.pressed.connect(_go_to_start)
		continue_button.grab_focus() # optional: direkt Fokus auf Button

func _unhandled_input(event: InputEvent) -> void:
	# Enter / Escape drücken -> Startmenü
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_ESCAPE:
			_go_to_start()

func _go_to_start() -> void:
	get_tree().change_scene_to_file(START_SCENE)
