extends Control

signal start_new_pressed

const SETTINGS_MENU_SCENE := preload("res://scenes/UI/settings_menu.tscn")
const MAP_GENERATOR_SCENE := preload("res://scenes/testscene2/Map_Generator.tscn")

var cursor_idle = preload("res://assets/menu/normal.png")
var cursor_click = preload("res://assets/menu/clicked.png")

var _settings_instance: Control = null
var _settings_layer: CanvasLayer = null

@onready var bg_music = $bg_music

func _ready():

	# 👉 Reset ALL autoloads cleanly (kein new(), kein instantiate!)
	if Engine.has_singleton("AutoloadResetRunner"):
		AutoloadResetRunner.reset_all()

	# Cursor setzen
	Input.set_custom_mouse_cursor(cursor_idle)

	# Musik soft starten
	if bg_music:
		bg_music.volume_db = -80.0
		bg_music.play(13.0)

		var fade_tween = create_tween()
		fade_tween.tween_property(
			bg_music,
			"volume_db",
			0.0,
			2.0
		).set_trans(Tween.TRANS_SINE)

	_wire_buttons()
	_setup_focus_navigation()


# ==========================
# BUTTON WIRING
# ==========================

func _wire_buttons() -> void:

	if has_node("BoxContainer/VBoxContainer2/Settings"):
		$BoxContainer/VBoxContainer2/Settings.pressed.connect(_open_settings)

	if has_node("BoxContainer/VBoxContainer2/Start New"):
		$"BoxContainer/VBoxContainer2/Start New".pressed.connect(_on_start_pressed)

	if has_node("BoxContainer/VBoxContainer2/Exit"):
		$BoxContainer/VBoxContainer2/Exit.pressed.connect(get_tree().quit)


# ==========================
# START GAME
# ==========================

func _on_start_pressed() -> void:

	emit_signal("start_new_pressed")

	# 👉 WICHTIG: kompletter Szenenwechsel
	get_tree().paused = false
	get_tree().change_scene_to_packed(MAP_GENERATOR_SCENE)


# ==========================
# CURSOR HANDLING
# ==========================

func _input(event):

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:

		if event.pressed:
			Input.set_custom_mouse_cursor(cursor_click)
		else:
			Input.set_custom_mouse_cursor(cursor_idle)


# ==========================
# SETTINGS OVERLAY
# ==========================

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
	_settings_instance.offset_left = 0
	_settings_instance.offset_top = 0
	_settings_instance.offset_right = 0
	_settings_instance.offset_bottom = 0

	if _settings_instance.has_signal("closed"):
		_settings_instance.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void:

	if _settings_layer:
		_settings_layer.queue_free()

	_settings_layer = null
	_settings_instance = null


func _setup_focus_navigation():

	if not has_node("BoxContainer/VBoxContainer2"):
		return

	var container = $BoxContainer/VBoxContainer2

	for child in container.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_ALL

	# Fokus auf ersten Button
	container.get_child(0).grab_focus()
