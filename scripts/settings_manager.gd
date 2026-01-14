extends Node

const SETTINGS_PATH := "user://settings.json"
const SCHEMA_VERSION := 1

# Settings are stored as a nested dictionary:
# {
#   "schema_version": int,
#   "display": { ... },
#   "sound": { ... },
#   "hotkeys": { "actions": { action_name: { ...serialized event... } } },
#   "game": { ... }
# }
var settings: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply_all()


func get_settings() -> Dictionary:
	return settings


func load_settings() -> void:
	var defaults := _get_defaults()
	var loaded := _read_json(SETTINGS_PATH)
	settings = _deep_merge_defaults(loaded, defaults)
	settings["schema_version"] = SCHEMA_VERSION
	_save_json(SETTINGS_PATH, settings)


func save_settings() -> void:
	if settings.is_empty():
		settings = _get_defaults()
	settings["schema_version"] = SCHEMA_VERSION
	_save_json(SETTINGS_PATH, settings)


func set_value(path: Array, value) -> void:
	if settings.is_empty():
		load_settings()
	var cursor: Dictionary = settings
	for i in range(path.size() - 1):
		var key = path[i]
		if not cursor.has(key) or typeof(cursor[key]) != TYPE_DICTIONARY:
			cursor[key] = {}
		cursor = cursor[key] as Dictionary
	cursor[path[path.size() - 1]] = value


func get_value(path: Array, fallback = null):
	var cursor: Variant = settings
	for key in path:
		if typeof(cursor) != TYPE_DICTIONARY or not cursor.has(key):
			return fallback
		cursor = cursor[key]
	return cursor


func apply_all() -> void:
	apply_display()
	apply_sound()
	apply_hotkeys()


func apply_display() -> void:
	var display := settings.get("display", {}) as Dictionary
	var mode := String(display.get("window_mode", "windowed"))
	match mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var vsync_enabled := bool(display.get("vsync", true))
	var vsync_mode := DisplayServer.VSYNC_ENABLED
	if not vsync_enabled:
		vsync_mode = DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)


func apply_sound() -> void:
	var sound := settings.get("sound", {}) as Dictionary
	var mute := bool(sound.get("mute", false))
	var volume_percent := float(sound.get("master_volume", 100.0))
	volume_percent = clampf(volume_percent, 0.0, 100.0)

	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx < 0:
		return

	if mute or volume_percent <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
		AudioServer.set_bus_volume_db(bus_idx, -80.0)
		return

	AudioServer.set_bus_mute(bus_idx, false)
	var linear := maxf(volume_percent / 100.0, 0.0001)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))


func apply_hotkeys() -> void:
	var hotkeys := settings.get("hotkeys", {}) as Dictionary
	var actions := hotkeys.get("actions", {}) as Dictionary

	for action_name in actions.keys():
		if not InputMap.has_action(action_name):
			continue
		var serialized = actions[action_name]
		var evt := _deserialize_input_event(serialized)
		if evt == null:
			continue

		# Remove only keyboard events to avoid wiping future gamepad bindings.
		var existing := InputMap.action_get_events(action_name)
		for e in existing:
			if e is InputEventKey:
				InputMap.action_erase_event(action_name, e)
		InputMap.action_add_event(action_name, evt)


func set_hotkey(action_name: String, key_event: InputEventKey) -> void:
	if settings.is_empty():
		load_settings()
	if not settings.has("hotkeys"):
		settings["hotkeys"] = {}
	if not settings["hotkeys"].has("actions"):
		settings["hotkeys"]["actions"] = {}

	settings["hotkeys"]["actions"][action_name] = _serialize_input_event(key_event)


func get_rebindable_actions() -> Array[String]:
	# Include both built-in UI actions and the project's move_* ones if present.
	var candidates: Array[String] = [
		"ui_menu",
		"ui_up",
		"ui_down",
		"ui_left",
		"ui_right",
		"move_up",
		"move_down",
		"move_left",
		"move_right",
	]
	var out: Array[String] = []
	for a in candidates:
		if InputMap.has_action(a):
			out.append(a)
	return out


func get_current_key_text(action_name: String) -> String:
	# Prefer configured hotkey if present, otherwise show current InputMap keyboard binding.
	var configured = get_value(["hotkeys", "actions", action_name], null)
	var evt := _deserialize_input_event(configured) if configured != null else null
	if evt == null:
		for e in InputMap.action_get_events(action_name):
			if e is InputEventKey:
				evt = e
				break
	if evt == null:
		return "(unbound)"
	return _key_event_to_text(evt)


func _get_defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"display":
		{
			"window_mode": "windowed",
			"vsync": true,
		},
		"sound":
		{
			"master_volume": 100.0,
			"mute": false,
		},
		"hotkeys":
		{
			"actions": _get_default_hotkeys(),
		},
		"game":
		{
			"placeholder_option": true,
		},
	}


func _get_default_hotkeys() -> Dictionary:
	var defaults := {}
	for action_name in get_rebindable_actions():
		var evt: InputEventKey = null
		for e in InputMap.action_get_events(action_name):
			if e is InputEventKey:
				evt = e
				break
		if evt != null:
			defaults[action_name] = _serialize_input_event(evt)
	return defaults


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	if text.strip_edges().is_empty():
		return {}

	var parser := JSON.new()
	var err := parser.parse(text)
	if err != OK:
		return {}
	var data = parser.data
	return data if typeof(data) == TYPE_DICTIONARY else {}


func _save_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "  ", false))
	f.close()


func _deep_merge_defaults(existing: Dictionary, defaults: Dictionary) -> Dictionary:
	# Returns a merged dictionary with:
	# - Defaults always present
	# - Existing values overriding defaults when compatible
	# - Unknown extra keys preserved
	var merged: Dictionary = {}

	# Start with defaults.
	for k in defaults.keys():
		var dv = defaults[k]
		merged[k] = dv

	# Overlay existing.
	for k in existing.keys():
		var ev = existing[k]
		if merged.has(k):
			var dv = merged[k]
			if typeof(dv) == TYPE_DICTIONARY and typeof(ev) == TYPE_DICTIONARY:
				merged[k] = _deep_merge_defaults(ev, dv)
			elif typeof(ev) == typeof(dv) or dv == null:
				merged[k] = ev
			else:
				# Type mismatch: keep default.
				pass
		else:
			# Unknown key: preserve.
			merged[k] = ev

	return merged


func _serialize_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var e := event as InputEventKey
		return {
			"type": "key",
			"keycode": int(e.keycode),
			"physical_keycode": int(e.physical_keycode),
			"ctrl": bool(e.ctrl_pressed),
			"shift": bool(e.shift_pressed),
			"alt": bool(e.alt_pressed),
			"meta": bool(e.meta_pressed),
		}
	return {"type": "unknown"}


func _deserialize_input_event(serialized) -> InputEvent:
	if typeof(serialized) != TYPE_DICTIONARY:
		return null
	if String(serialized.get("type", "")) != "key":
		return null

	var e := InputEventKey.new()
	e.keycode = int(serialized.get("keycode", 0))
	e.physical_keycode = int(serialized.get("physical_keycode", 0))
	e.ctrl_pressed = bool(serialized.get("ctrl", false))
	e.shift_pressed = bool(serialized.get("shift", false))
	e.alt_pressed = bool(serialized.get("alt", false))
	e.meta_pressed = bool(serialized.get("meta", false))
	return e


func _key_event_to_text(e: InputEventKey) -> String:
	var parts: Array[String] = []
	if e.ctrl_pressed:
		parts.append("Ctrl")
	if e.shift_pressed:
		parts.append("Shift")
	if e.alt_pressed:
		parts.append("Alt")
	if e.meta_pressed:
		parts.append("Meta")

	var key_name := OS.get_keycode_string(e.keycode if e.keycode != 0 else e.physical_keycode)
	if key_name.is_empty():
		key_name = "(unknown)"
	parts.append(key_name)
	return "+".join(parts)
