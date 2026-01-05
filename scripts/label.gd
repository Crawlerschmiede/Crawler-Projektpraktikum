extends Label

@export var bob_speed: float = 2.0  # How fast it moves up and down
@export var bob_height: float = 5.0  # How many pixels it travels
@export var rotate_sway: float = 2.0  # Optional: Subtle tilt (in degrees)

var time: float = 0.0
@onready var start_y: float = position.y


func _process(delta):
	time += delta

	# 1. Calculate the vertical offset using a Sine wave
	# Formula: start_position + (sin(time * speed) * height)
	var offset = sin(time * bob_speed) * bob_height
	position.y = start_y + offset

	# 2. Optional: Add a very slight rotation sway
	var rotation_offset = sin(time * (bob_speed * 0.8)) * rotate_sway
	rotation_degrees = rotation_offset
