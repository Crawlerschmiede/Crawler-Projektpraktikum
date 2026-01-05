extends Control

var cursor_idle = preload("res://assets/menu/normal.png")
var cursor_click = preload("res://assets/menu/clicked.png")


func _ready():
	Input.set_custom_mouse_cursor(cursor_idle)


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			Input.set_custom_mouse_cursor(cursor_click)
		else:
			Input.set_custom_mouse_cursor(cursor_idle)
