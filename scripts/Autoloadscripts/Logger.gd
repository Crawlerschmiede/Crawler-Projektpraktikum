extends Node

enum Level { DEBUG, INFO, WARN, ERROR }

@export var level: int = Level.INFO
@export var write_to_file: bool = false
@export var log_file_path: String = "user://game.log"

var _file: FileAccess = null


func _open_file() -> void:
	if _file != null:
		return
	_file = FileAccess.open(log_file_path, FileAccess.WRITE_READ)
	if _file == null:
		# Try create file
		_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if _file != null:
		_file.close()


func _append_to_file(text: String) -> void:
	if not write_to_file:
		return
	_open_file()
	var f = FileAccess.open(log_file_path, FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	f.store_line(text)
	f.close()


# Convenience varargs helpers: allow calling Logger.infov("a", b, c)
func _join_args(args: Array) -> String:
	var out: String = ""
	var first := true
	for a in args:
		if not first:
			out += " "
		out += str(a)
		first = false
	return out


func reset() -> void:
	# Close any open file handle and reset file state
	if _file != null:
		_file.close()
	_file = null
