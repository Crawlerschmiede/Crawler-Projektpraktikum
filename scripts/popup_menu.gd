extends CanvasLayer

# custom signal to inform the main scene
signal menu_closed

# Called when the scene is loaded
func _ready():

	var continue_button = $VBoxContainer/Button
	var quit_button = $VBoxContainer/Button2


# Function for the "Continue" button
func _on_continue_pressed():
	print("Check:Continue Pressed. Emitting signal.")
	menu_closed.emit()

# Function for the "Quit" button
func _on_quit_pressed():
	print("Check: Quit Pressed! Emitting signal.")
	get_tree().quit()
