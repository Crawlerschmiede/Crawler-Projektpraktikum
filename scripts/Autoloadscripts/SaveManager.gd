extends Node

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

var pending_continue: bool = false

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func save_state(state: Dictionary) -> bool:
	# state wird vom GameState geliefert
	var wrapper := {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"state": state
	}

	var json := JSON.stringify(wrapper, "\t")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager.save_state: failed to open save file for writing")
		return false

	f.store_string(json)
	f.close()
	return true

func load_state() -> Dictionary:
	if not has_save():
		return {}

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("SaveManager.load_state: failed to open save file for reading")
		return {}

	var txt := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager.load_state: invalid JSON root")
		return {}

	var root: Dictionary = parsed
	var version := int(root.get("version", -1))
	if version != SAVE_VERSION:
		push_warning("SaveManager.load_state: save version mismatch: %s" % version)
		# optional: Migration hier
		# return {}
	
	var state = root.get("state", {})
	if typeof(state) != TYPE_DICTIONARY:
		return {}
	return state
