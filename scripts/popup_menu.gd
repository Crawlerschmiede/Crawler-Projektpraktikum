extends CanvasLayer

# custom signal to inform the main scene
signal menu_closed

const SETTINGS_MENU_SCENE := preload("res://scenes/settings_menu.tscn")

var _settings_instance: Control = null
var _settings_layer: CanvasLayer = null


# Called when the scene is loaded
func _ready():
	var continue_button = $VBoxContainer/Button
	var quit_button = $VBoxContainer/Button2


# Function for the "Continue" button
func _on_continue_pressed():
	print("Check:Continue Pressed. Emitting signal.")
	menu_closed.emit()


func _on_settings_pressed() -> void:
	if _settings_instance != null:
		return
	$VBoxContainer.visible = false
	_settings_layer = CanvasLayer.new()
	_settings_layer.name = "SettingsOverlay"
	_settings_layer.layer = 100
	get_tree().root.add_child(_settings_layer)

	_settings_instance = SETTINGS_MENU_SCENE.instantiate()
	_settings_layer.add_child(_settings_instance)
	_settings_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_instance.offset_left = 0.0
	_settings_instance.offset_top = 0.0
	_settings_instance.offset_right = 0.0
	_settings_instance.offset_bottom = 0.0
	if _settings_instance.has_signal("closed"):
		_settings_instance.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	if _settings_layer != null:
		_settings_layer.queue_free()
		_settings_layer = null
	_settings_instance = null
	$VBoxContainer.visible = true


# Function for the "Quit" button
func _on_quit_pressed():
	print("Check: Quit Pressed! Emitting signal.")
	get_tree().quit()
