extends Control

signal closed

const SETTINGS_MANAGER_PATH := "/root/SettingsManager"

const PATH_TAB_CONTAINER := NodePath("PanelContainer/VBoxContainer/TabContainer")
const PATH_WINDOW_MODE := NodePath("PanelContainer/VBoxContainer/TabContainer/Display/WindowMode")
const PATH_VSYNC := NodePath("PanelContainer/VBoxContainer/TabContainer/Display/VSync")
const PATH_MASTER_VOLUME := NodePath("PanelContainer/VBoxContainer/TabContainer/Sound/MasterVolume")
const PATH_MUTE := NodePath("PanelContainer/VBoxContainer/TabContainer/Sound/Mute")
const PATH_HOTKEY_LIST := NodePath(
	"PanelContainer/VBoxContainer/TabContainer/Hotkeys/Scroll/ActionsList"
)
const PATH_HOTKEY_HINT := NodePath("PanelContainer/VBoxContainer/TabContainer/Hotkeys/RebindHint")

var _rebind_action: String = ""
var _rows_by_action: Dictionary = {}

@onready var tab_container: TabContainer = get_node(PATH_TAB_CONTAINER)

# Display tab
@onready var window_mode: OptionButton = get_node(PATH_WINDOW_MODE)
@onready var vsync: CheckBox = get_node(PATH_VSYNC)

# Sound tab
@onready var master_volume: HSlider = get_node(PATH_MASTER_VOLUME)
@onready var mute: CheckBox = get_node(PATH_MUTE)

# Hotkeys tab
@onready var hotkey_list: VBoxContainer = get_node(PATH_HOTKEY_LIST)
@onready var hotkey_hint: Label = get_node(PATH_HOTKEY_HINT)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_window_mode_items()
	_refresh_from_settings()
	_build_hotkey_rows()

	window_mode.item_selected.connect(_on_window_mode_changed)
	vsync.toggled.connect(_on_vsync_toggled)
	master_volume.value_changed.connect(_on_master_volume_changed)
	mute.toggled.connect(_on_mute_toggled)


func _ensure_window_mode_items() -> void:
	if window_mode.item_count > 0:
		return
	window_mode.add_item("Windowed")
	window_mode.add_item("Fullscreen")


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
	window_mode.select(0 if mode != "fullscreen" else 1)
	vsync.button_pressed = bool(mgr.get_value(["display", "vsync"], true))

	# Sound
	master_volume.value = float(mgr.get_value(["sound", "master_volume"], 100.0))
	mute.button_pressed = bool(mgr.get_value(["sound", "mute"], false))


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
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var key_label := Label.new()
		key_label.text = mgr.get_current_key_text(action_name)
		key_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(key_label)

		var rebind := Button.new()
		rebind.text = "Rebind"
		rebind.pressed.connect(_begin_rebind.bind(action_name))
		row.add_child(rebind)

		hotkey_list.add_child(row)
		_rows_by_action[action_name] = {
			"key_label": key_label,
			"button": rebind,
		}

	_update_rebind_hint()


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
	_rebind_action = ""
	_update_rebind_hint()


func _update_rebind_hint() -> void:
	if _rebind_action.is_empty():
		hotkey_hint.text = "Click Rebind, then press a key (Esc cancels)."
	else:
		hotkey_hint.text = "Rebinding: %s (press a key, Esc cancels)." % _rebind_action


func _on_window_mode_changed(idx: int) -> void:
	var mgr = _get_manager()
	if mgr == null:
		return
	var mode := "windowed" if idx == 0 else "fullscreen"
	mgr.set_value(["display", "window_mode"], mode)
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


func _on_back_pressed() -> void:
	closed.emit()


func _on_close_pressed() -> void:
	closed.emit()
