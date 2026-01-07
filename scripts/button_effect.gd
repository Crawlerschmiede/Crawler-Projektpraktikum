extends Button

@export var outline_color: Color = Color("ffeca5ff")
@export var outline_size: int = 1


func _ready():
	add_theme_constant_override("outline_size", 0)
	add_theme_color_override("font_outline_color", outline_color)
	# Connect the signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

	# Set the pivot to the center so it scales evenly
	pivot_offset = size / 2


func _on_mouse_entered():
	pivot_offset = size / 2
	# Scale up slightly when hovered
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_method(set_outline_thickness, 0, outline_size, 0.1)
	# Change color
	modulate = Color(1.2, 1.2, 1.2)  # Makes it slightly "glow"


func _on_mouse_exited():
	pivot_offset = size / 2  # Return to normal size
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tween.parallel().tween_method(set_outline_thickness, outline_size, 0, 0.1)
	modulate = Color(1, 1, 1)


func _on_button_down():
	# Squash it down when clicked
	scale = Vector2(0.95, 0.95)


func _on_button_up():
	# Pop back to hover size
	scale = Vector2(1.1, 1.1)


func set_outline_thickness(value: int):
	add_theme_constant_override("outline_size", value)
