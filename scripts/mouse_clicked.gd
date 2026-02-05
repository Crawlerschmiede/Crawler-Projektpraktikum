extends CanvasLayer

const SETTINGS_MENU_SCENE := preload("res://scenes/settings_menu.tscn")

var cursor_idle = preload("res://assets/menu/normal.png")
var cursor_click = preload("res://assets/menu/clicked.png")

var _settings_instance: Control = null
var _settings_layer: CanvasLayer = null

@onready var bg_music = $bg_music

signal start_new_pressed

@onready var on_start = $"BoxContainer/VBoxContainer2/Start New"
@onready var map_generator = preload("res://scenes/testscene2/Map_Generator.tscn")

func _ready():
	Input.set_custom_mouse_cursor(cursor_idle)
	if bg_music:
		# 1. Set volume to silent (-80dB) BEFORE playing
		bg_music.volume_db = -80.0

		# 2. Start playing at the 10.0 second mark
		bg_music.play(13.0)

		# 3. Create a separate tween to fade the volume in softly
		var fade_tween = create_tween()
		fade_tween.tween_property(bg_music, "volume_db", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
	_wire_start_menu_buttons()


func _wire_start_menu_buttons() -> void:
	# Start menu has these nodes; if this script is reused elsewhere, fail gracefully.
	if not has_node("BoxContainer/VBoxContainer2/Settings"):
		return
	var settings_btn: Button = $BoxContainer/VBoxContainer2/Settings
	settings_btn.pressed.connect(_open_settings)

	# Wire Start New button to emit a signal so the parent scene can react (start new game)
	if has_node("BoxContainer/VBoxContainer2/Start New"):
		var start_btn = $"BoxContainer/VBoxContainer2/Start New"
		start_btn.pressed.connect(_on_start_pressed)

	if has_node("BoxContainer/VBoxContainer2/Exit"):
		var exit_btn: Button = $BoxContainer/VBoxContainer2/Exit
		exit_btn.pressed.connect(get_tree().quit)


func _on_start_pressed() -> void:
	emit_signal("start_new_pressed")
	# Wechsel zur Map-Generator-Szene (Start-Spiel)
	if map_generator != null:
		var gen_instance = map_generator.instantiate()
		# Add generator as child of the root so it becomes active
		get_tree().get_root().add_child(gen_instance)
		# Free the start menu (deferred to avoid freeing while handling signals)
		call_deferred("queue_free")


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
	if _settings_layer != null:
		_settings_layer.layer = 100
	else:
		push_error("_open_settings: failed to create _settings_layer")
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
