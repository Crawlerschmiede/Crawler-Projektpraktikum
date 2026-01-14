extends Control

const SETTINGS_MENU_SCENE := preload("res://scenes/settings_menu.tscn")

var cursor_idle = preload("res://assets/menu/normal.png")
var cursor_click = preload("res://assets/menu/clicked.png")

var _settings_instance: Control = null
var _settings_layer: CanvasLayer = null


func _ready():
	Input.set_custom_mouse_cursor(cursor_idle)
	_wire_start_menu_buttons()


func _wire_start_menu_buttons() -> void:
	# Start menu has these nodes; if this script is reused elsewhere, fail gracefully.
	if not has_node("BoxContainer/VBoxContainer2/Settings"):
		return
	var settings_btn: Button = $BoxContainer/VBoxContainer2/Settings
	settings_btn.pressed.connect(_open_settings)

	if has_node("BoxContainer/VBoxContainer2/Exit"):
		var exit_btn: Button = $BoxContainer/VBoxContainer2/Exit
		exit_btn.pressed.connect(get_tree().quit)


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			Input.set_custom_mouse_cursor(cursor_click)
		else:
			Input.set_custom_mouse_cursor(cursor_idle)


func _open_settings() -> void:
	if _settings_instance != null:
		return
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
