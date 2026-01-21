extends RefCounted
class_name RoomLibrary

var room_scenes: Array[PackedScene] = []
var corridor_cache := {}


func load_rooms(path: String) -> void:
	room_scenes.clear()
	room_scenes = _load_scenes_from_folder(path)


func _load_scenes_from_folder(path: String) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Folder not found: " + path)
		return result

	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tscn"):
			var ps := load(path + file)
			if ps is PackedScene:
				result.append(ps)
		file = dir.get_next()

	dir.list_dir_end()
	return result


func is_corridor(scene: PackedScene) -> bool:
	if scene == null:
		return false
	var key := scene.resource_path
	if corridor_cache.has(key):
		return corridor_cache[key]

	var inst := scene.instantiate()
	var corr := inst != null and ("is_corridor" in inst) and bool(inst.get("is_corridor"))
	if inst:
		inst.queue_free()

	corridor_cache[key] = corr
	return corr
