extends Control

signal closed

const SETTINGS_MANAGER_PATH := "/root/SettingsManager"

const PATH_TAB_CONTAINER := NodePath("PanelContainer/VBoxContainer/TabContainer")
const PATH_WINDOW_MODE := NodePath("PanelContainer/VBoxContainer/TabContainer/Display/WindowMode")
const PATH_RESOLUTION := NodePath("PanelContainer/VBoxContainer/TabContainer/Display/Resolution")
const PATH_VSYNC := NodePath("PanelContainer/VBoxContainer/TabContainer/Display/VSync")
const PATH_MASTER_VOLUME := NodePath("PanelContainer/VBoxContainer/TabContainer/Sound/MasterVolume")
const PATH_MUTE := NodePath("PanelContainer/VBoxContainer/TabContainer/Sound/Mute")
const PATH_ZOOM_LEVEL := NodePath("PanelContainer/VBoxContainer/TabContainer/Game/ZoomLevel")
const PATH_HOTKEY_LIST := NodePath(
	"PanelContainer/VBoxContainer/TabContainer/Hotkeys/Scroll/ActionsList"
)
const PATH_HOTKEY_HINT := NodePath("PanelContainer/VBoxContainer/TabContainer/Hotkeys/RebindHint")

var custom_font = load("res://assets/font/PixelPurl.ttf")

var _rebind_action: String = ""
var _rows_by_action: Dictionary = {}
var _resolution_items: Array[Vector2i] = []

@onready var tab_container: TabContainer = get_node(PATH_TAB_CONTAINER)

# Display tab
@onready var window_mode: OptionButton = get_node(PATH_WINDOW_MODE)
@onready var resolution: OptionButton = get_node(PATH_RESOLUTION)
@onready var vsync: CheckBox = get_node(PATH_VSYNC)

# Sound tab
@onready var master_volume: HSlider = get_node(PATH_MASTER_VOLUME)
@onready var mute: CheckBox = get_node(PATH_MUTE)

# Game tab
@onready var zoom_level: HSlider = get_node(PATH_ZOOM_LEVEL)

# Hotkeys tab
@onready var hotkey_list: VBoxContainer = get_node(PATH_HOTKEY_LIST)
@onready var hotkey_hint: Label = get_node(PATH_HOTKEY_HINT)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_window_mode_items()
	_build_resolution_items()
	_refresh_from_settings()
	_build_hotkey_rows()

	#Thene overrides
	window_mode.get_popup().add_theme_font_override("font", custom_font)
	resolution.get_popup().add_theme_font_override("font", custom_font)
	# Sound Tab
	mute.add_theme_font_override("font", custom_font)
	# Hotkeys Hint
	hotkey_hint.add_theme_font_override("font", custom_font)
	# TabContainer Headers
	tab_container.add_theme_font_override("font", custom_font)

	window_mode.item_selected.connect(_on_window_mode_changed)
	resolution.item_selected.connect(_on_resolution_changed)
	vsync.toggled.connect(_on_vsync_toggled)
	master_volume.value_changed.connect(_on_master_volume_changed)
	mute.toggled.connect(_on_mute_toggled)
	zoom_level.value_changed.connect(_on_zoom_level_changed)


func _ensure_window_mode_items() -> void:
	if window_mode.item_count > 0:
		return
	window_mode.add_item("Windowed")
	window_mode.add_item("Borderless Fullscreen")
	window_mode.add_item("Exclusive Fullscreen")
	window_mode.add_theme_font_override("font", custom_font)


func _build_resolution_items() -> void:
	resolution.clear()
	_resolution_items.clear()
	resolution.add_theme_font_override("font", custom_font)

	var available: Array[Vector2i] = _get_available_resolutions()
	for res_size in available:
		resolution.add_item("%dx%d" % [res_size.x, res_size.y])
		_resolution_items.append(res_size)


func _unhandled_input(event: InputEvent) -> void:
	if _rebind_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var e := event as InputEventKey
		if e.keycode == KEY_ESCAPE:
			_cancel_rebind()
			accept_event()
			return

		_set_rebind_key(e)
		accept_event()


func _get_manager():
	return get_node(SETTINGS_MANAGER_PATH) if has_node(SETTINGS_MANAGER_PATH) else null


func _refresh_from_settings() -> void:
	var mgr = _get_manager()
	if mgr == null:
		return

	# Display
	var mode := String(mgr.get_value(["display", "window_mode"], "windowed"))
	var fs_type := String(mgr.get_value(["display", "fullscreen_type"], "borderless"))
	match mode:
		"borderless_fullscreen":
			window_mode.select(1)
		"exclusive_fullscreen":
			window_mode.select(2)
		"fullscreen":
			window_mode.select(2 if fs_type == "exclusive" else 1)
		_:
			window_mode.select(0)
	_select_resolution_from_settings()
	vsync.button_pressed = bool(mgr.get_value(["display", "vsync"], true))
	_update_display_controls_state()

	# Sound
	master_volume.value = float(mgr.get_value(["sound", "master_volume"], 100.0))
	mute.button_pressed = bool(mgr.get_value(["sound", "mute"], false))

	# Game
	var zoom_steps: int = mgr.get_zoom_steps()
	zoom_steps = max(zoom_steps, 0)
	zoom_level.min_value = float(-zoom_steps)
	zoom_level.max_value = float(zoom_steps)
	zoom_level.step = 1
	zoom_level.value = float(clampi(mgr.get_zoom_level(), -zoom_steps, zoom_steps))


func _build_hotkey_rows() -> void:
	var mgr = _get_manager()
	if mgr == null:
		return

	for child in hotkey_list.get_children():
		child.queue_free()
	_rows_by_action.clear()

	for action_name in mgr.get_rebindable_actions():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.text = action_name
		name_label.add_theme_font_override("font", custom_font)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var key_label := Label.new()
		key_label.text = mgr.get_current_key_text(action_name)
		key_label.add_theme_font_override("font", custom_font)
		key_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(key_label)

		var rebind := Button.new()
		rebind.text = "Rebind"
		rebind.add_theme_font_override("font", custom_font)
		rebind.pressed.connect(_begin_rebind.bind(action_name))
		row.add_child(rebind)

		hotkey_list.add_child(row)
		_rows_by_action[action_name] = {
			"key_label": key_label,
			"button": rebind,
		}

	_update_rebind_hint()


func _get_available_resolutions() -> Array[Vector2i]:
	var resolutions: Array[Vector2i] = []

	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	if screen_size.x > 0 and screen_size.y > 0:
		resolutions.append(Vector2i(screen_size.x, screen_size.y))

	var common: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1366, 768),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	]
	for res_size in common:
		if screen_size.x > 0 and screen_size.y > 0:
			if res_size.x > screen_size.x or res_size.y > screen_size.y:
				continue
		if not resolutions.has(res_size):
			resolutions.append(res_size)

	var current := DisplayServer.window_get_size()
	var current_size := Vector2i(current.x, current.y)
	if current_size.x > 0 and current_size.y > 0 and not resolutions.has(current_size):
		resolutions.append(current_size)

	resolutions.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.x == b.x else a.x < b.x
	)
	return resolutions


func _select_resolution_from_settings() -> void:
	var mgr = _get_manager()
	if mgr == null:
		return

	var res: Dictionary = mgr.get_value(["display", "resolution"], {}) as Dictionary
	var width := int(res.get("width", 640))
	var height := int(res.get("height", 480))
	var target := Vector2i(width, height)

	var idx := _resolution_items.find(target)
	if idx == -1:
		resolution.add_item("%dx%d" % [target.x, target.y])
		_resolution_items.append(target)
		idx = _resolution_items.size() - 1

	resolution.select(idx)


func _update_display_controls_state() -> void:
	var is_fullscreen := window_mode.selected != 0
	var borderless := window_mode.selected == 1
	resolution.disabled = is_fullscreen and borderless


func _update_hotkey_label(action_name: String) -> void:
	var mgr = _get_manager()
	if mgr == null:
		return
	if not _rows_by_action.has(action_name):
		return
	var key_label: Label = _rows_by_action[action_name]["key_label"]
	key_label.text = mgr.get_current_key_text(action_name)


func _begin_rebind(action_name: String) -> void:
	if not _rebind_action.is_empty():
		_cancel_rebind()
	_rebind_action = action_name

	if _rows_by_action.has(action_name):
		var btn: Button = _rows_by_action[action_name]["button"]
		btn.text = "Press key..."
		btn.add_theme_font_override("font", custom_font)
	_update_rebind_hint()


func _set_rebind_key(e: InputEventKey) -> void:
	var mgr = _get_manager()
	if mgr == null:
		_cancel_rebind()
		return

	mgr.set_hotkey(_rebind_action, e)
	mgr.apply_hotkeys()
	mgr.save_settings()
	_update_hotkey_label(_rebind_action)

	_cancel_rebind()


func _cancel_rebind() -> void:
	if _rebind_action.is_empty():
		return
	if _rows_by_action.has(_rebind_action):
		var btn: Button = _rows_by_action[_rebind_action]["button"]
		btn.text = "Rebind"
		btn.add_theme_font_override("font", custom_font)
	_rebind_action = ""
	_update_rebind_hint()


func _update_rebind_hint() -> void:
	if _rebind_action.is_empty():
		hotkey_hint.text = " Click Rebind, then press a key (Esc cancels)."
		hotkey_hint.add_theme_font_override("font", custom_font)
	else:
		hotkey_hint.text = " Rebinding: %s (press a key, Esc cancels)." % _rebind_action


func _on_window_mode_changed(idx: int) -> void:
	var mgr = _get_manager()
	if mgr == null:
		return
	var mode := "windowed"
	var fs_type := "borderless"
	if idx == 1:
		mode = "borderless_fullscreen"
		fs_type = "borderless"
	elif idx == 2:
		mode = "exclusive_fullscreen"
		fs_type = "exclusive"
	mgr.set_value(["display", "window_mode"], mode)
	mgr.set_value(["display", "fullscreen_type"], fs_type)
	_update_display_controls_state()
	mgr.apply_display()
	mgr.save_settings()


func _on_resolution_changed(idx: int) -> void:
	var mgr = _get_manager()
	if mgr == null:
		return
	if idx < 0 or idx >= _resolution_items.size():
		return
	var selected_size := _resolution_items[idx]
	mgr.set_value(["display", "resolution"], {"width": selected_size.x, "height": selected_size.y})
	mgr.apply_display()
	mgr.save_settings()


func _on_vsync_toggled(enabled: bool) -> void:
	var mgr = _get_manager()
	if mgr == null:
		return
	mgr.set_value(["display", "vsync"], enabled)
	mgr.apply_display()
	mgr.save_settings()


func _on_master_volume_changed(value: float) -> void:
	var mgr = _get_manager()
	if mgr == null:
		return
	mgr.set_value(["sound", "master_volume"], value)
	mgr.apply_sound()
	mgr.save_settings()


func _on_mute_toggled(enabled: bool) -> void:
	var mgr = _get_manager()
	if mgr == null:
		return
	mgr.set_value(["sound", "mute"], enabled)
	mgr.apply_sound()
	mgr.save_settings()


func _on_zoom_level_changed(value: float) -> void:
	var mgr = _get_manager()
	if mgr == null:
		return
	var zoom_steps: int = mgr.get_zoom_steps()
	zoom_steps = max(zoom_steps, 0)
	var step_value := clampi(int(round(value)), -zoom_steps, zoom_steps)
	if int(zoom_level.value) != step_value:
		zoom_level.value = step_value
	mgr.set_value(["game", "zoom_level"], step_value)
	mgr.apply_game()
	mgr.save_settings()


func _on_back_pressed() -> void:
	closed.emit()


func _on_close_pressed() -> void:
	closed.emit()
