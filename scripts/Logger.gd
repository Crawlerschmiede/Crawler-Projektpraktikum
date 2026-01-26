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


func _format(level_name: String, msg: String) -> String:
	var t := 0
	return "%s [%s]: %s" % [str(t), level_name, msg]


func _log(level_name: String, lev: int, msg: String) -> void:
	if lev < level:
		return
	var out := _format(level_name, msg)
	match lev:
		Level.DEBUG, Level.INFO:
			print(out)
		Level.WARN:
			push_warning(out)
		Level.ERROR:
			push_error(out)
	_append_to_file(out)


func debug(msg: String) -> void:
	_log("DEBUG", Level.DEBUG, msg)


func info(msg: String) -> void:
	_log("INFO", Level.INFO, msg)


func warn(msg: String) -> void:
	_log("WARN", Level.WARN, msg)


func error(msg: String) -> void:
	_log("ERROR", Level.ERROR, msg)


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


func infov(...args) -> void:
	info(_join_args(args))


func debugv(...args) -> void:
	debug(_join_args(args))


func warnv(...args) -> void:
	warn(_join_args(args))


func errorv(...args) -> void:
	error(_join_args(args))
