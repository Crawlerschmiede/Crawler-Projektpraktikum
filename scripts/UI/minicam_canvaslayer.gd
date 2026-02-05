extends CanvasLayer

@export var zoom_step: float = 0.1
@export var zoom_min: float = 0.1
@export var zoom_max: float = 1

@onready var minicam: Camera2D = $SubViewportContainer/SubViewport/MiniCam


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		_change_zoom(-zoom_step)

	elif event.is_action_pressed("zoom_out"):
		_change_zoom(zoom_step)


func _change_zoom(amount: float) -> void:
	# Camera2D zoom: kleiner = näher ran, größer = weiter raus
	var new_zoom := minicam.zoom + Vector2(amount, amount)

	# clamp
	new_zoom.x = clamp(new_zoom.x, zoom_min, zoom_max)
	new_zoom.y = clamp(new_zoom.y, zoom_min, zoom_max)

	minicam.zoom = new_zoom
