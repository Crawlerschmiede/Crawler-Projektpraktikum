extends CanvasLayer

# custom signal to inform the main scene
signal menu_closed

const SETTINGS_MENU_SCENE := preload("res://scenes/UI/settings_menu.tscn")
const UI_MODAL_CONTROLLER := preload("res://scripts/UI/ui_modal_controller.gd")

const REFERENCE_SIZE := Vector2(640.0, 480.0)
const BASE_SCALE := Vector2(3.2, 2.8)

var _settings_instance: Control = null
var _settings_layer: CanvasLayer = null


# Called when the scene is loaded
func _ready():
	_apply_scale()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_apply_scale()


func _apply_scale() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var scale_factor: float = min(
		viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y
	)
	scale = BASE_SCALE * scale_factor


# Function for the "Continue" button
func _on_continue_pressed():
	#print("Check:Continue Pressed. Emitting signal.")
	menu_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			menu_closed.emit()
			get_viewport().set_input_as_handled()


func _on_settings_pressed() -> void:
	if _settings_instance != null:
		return
	UI_MODAL_CONTROLLER.acquire(self, true, true)
	$VBoxContainer.visible = false
	_settings_layer = CanvasLayer.new()
	_settings_layer.name = "SettingsOverlay"
	if _settings_layer != null:
		_settings_layer.layer = 100
	else:
		push_error("_on_settings_pressed: failed to create _settings_layer")
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
	UI_MODAL_CONTROLLER.release(self, true, true)


# Function for the "Quit" button
func _on_quit_pressed():
	#print("Check: Quit Pressed! Emitting signal.")
	get_tree().quit()
