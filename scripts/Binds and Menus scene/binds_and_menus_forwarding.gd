extends Control

signal closed

const SETTINGS_MENU_SCENE := preload("res://scenes/UI/settings_menu.tscn")
const POPUP_MENU_SCENE := preload("res://scenes/UI/popup-menu.tscn")
const UI_MODAL_CONTROLLER := preload("res://scripts/UI/ui_modal_controller.gd")

var _settings_layer: CanvasLayer = null
var _settings_instance: Control = null
var _menu_instance: CanvasLayer = null
var _inventory_transition_active: bool = false
var _inventory_seen_open: bool = false
var _close_hotkey_armed: bool = true


func _ready():
	# Loop through all children to find Buttons and Sprites
	for btn in find_children("*", "Button", true):
		btn.pressed.connect(_on_element_clicked.bind(btn.name))
	for sprite in find_children("*", "AnimatedSprite2D", true):
		# Check if the sprite has our custom signal before connecting
		if sprite.has_signal("clicked"):
			sprite.clicked.connect(_on_element_clicked)
	set_process(true)
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	if not _inventory_transition_active:
		return

	var inventory_visible := _is_inventory_open()
	if inventory_visible:
		_inventory_seen_open = true
		return

	if _inventory_seen_open and not inventory_visible:
		_inventory_transition_active = false
		_inventory_seen_open = false
		visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if not _close_hotkey_armed:
		if event.is_action_released("binds_and_menus"):
			_close_hotkey_armed = true
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("binds_and_menus"):
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("binds_and_menus"):
		closed.emit()
		get_viewport().set_input_as_handled()


func suppress_hotkey_close_until_release() -> void:
	_close_hotkey_armed = false


#func _input(event):
#	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
#		get_tree().change_scene_to_file("res://scenes/entity/player-character-scene.tscn")


func _on_element_clicked(element_name: String):
	print("Clicked: ", element_name)

	match element_name:
		"InventoryLabel", "InventoryIcon":
			_toggle_inventory()
			return

		"SettingsLabel", "SettingsIcon":
			_open_settings_overlay()
		"MenuLabel", "MenuIcon":
			_open_menu_overlay()


func _toggle_inventory() -> void:
	_inventory_transition_active = true
	_inventory_seen_open = false
	visible = false
	_trigger_action("open_inventory")


func _open_settings_overlay() -> void:
	if _settings_instance != null:
		return
	UI_MODAL_CONTROLLER.acquire(self, true, true)

	_settings_layer = CanvasLayer.new()
	_settings_layer.name = "SettingsOverlayFromBinds"
	_settings_layer.layer = 200
	get_tree().root.add_child(_settings_layer)

	_settings_instance = SETTINGS_MENU_SCENE.instantiate()
	_settings_layer.add_child(_settings_instance)

	if _settings_instance is Control:
		var overlay_control := _settings_instance as Control
		overlay_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_control.offset_left = 0.0
		overlay_control.offset_top = 0.0
		overlay_control.offset_right = 0.0
		overlay_control.offset_bottom = 0.0

	if _settings_instance.has_signal("closed"):
		_settings_instance.closed.connect(_on_settings_closed)
	else:
		push_error("_open_settings_overlay: settings instance missing 'closed' signal")

	visible = false


func _on_settings_closed() -> void:
	if _settings_layer != null:
		_settings_layer.queue_free()

	_settings_layer = null
	_settings_instance = null
	visible = true
	UI_MODAL_CONTROLLER.release(self, true, true)


func _open_menu_overlay() -> void:
	if _menu_instance != null:
		return
	UI_MODAL_CONTROLLER.acquire(self, true, true)

	_menu_instance = POPUP_MENU_SCENE.instantiate()
	get_tree().root.add_child(_menu_instance)

	if _menu_instance.has_signal("menu_closed"):
		_menu_instance.menu_closed.connect(_on_menu_closed)
	else:
		push_error("_open_menu_overlay: popup menu instance missing 'menu_closed' signal")

	# Connect save request from popup menu to local handler only if main doesn't handle it
	if _menu_instance.has_signal("save_requested"):
		var root := get_tree().root
		var handled := false
		if root.get_child_count() > 0:
			var maybe_main := root.get_child(0)
			if maybe_main != null and maybe_main.has_method("save_current_world"):
				handled = true
	else:
		push_error("_open_menu_overlay: popup menu instance missing 'save_requested' signal; save unavailable")

	visible = false


func _on_menu_closed() -> void:
	if _menu_instance != null:
		_menu_instance.queue_free()

	_menu_instance = null
	visible = true
	UI_MODAL_CONTROLLER.release(self, true, true)


func _on_save_requested() -> void:
	# Try to call save on the main scene if available
	var root := get_tree().root
	if root.get_child_count() == 0:
		push_error("_on_save_requested: no root children found to call save on")
		return
	var maybe_main := root.get_child(0)
	if maybe_main == null:
		push_error("_on_save_requested: root child is null")
		return
	if maybe_main.has_method("save_current_world"):
		maybe_main.call("save_current_world")
	else:
		push_error("_on_save_requested: main node has no save_current_world() method")


func _trigger_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		return

	var press_event := InputEventAction.new()
	press_event.action = action_name
	press_event.pressed = true
	Input.parse_input_event(press_event)

	var release_event := InputEventAction.new()
	release_event.action = action_name
	release_event.pressed = false
	Input.parse_input_event(release_event)


func _is_inventory_open() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false

	var inventory_inner := player.get_node_or_null("UserInterface/Inventory/Inner")
	if inventory_inner == null:
		return false

	if inventory_inner is CanvasItem:
		return (inventory_inner as CanvasItem).visible

	return false
