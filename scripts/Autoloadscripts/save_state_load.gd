extends Node

# Autoload singleton to coordinate save/load actions between UI and main
# Register this script as an Autoload with the name `SaveState` in Project Settings -> Autoload.

var load_from_save: bool = false


func should_load_from_save() -> bool:
	if load_from_save:
		return true

	var root := get_tree().root
	if root != null and root.has_meta("load_from_save"):
		return bool(root.get_meta("load_from_save"))

	return false


func set_should_load_from_save(value: bool) -> void:
	load_from_save = value

	var root := get_tree().root
	if root != null:
		root.set_meta("load_from_save", value)


func reset() -> void:
	set_should_load_from_save(false)
