class_name RoomManifestUtils

const ROOM_MANIFEST_PATH := "res://scenes/rooms/room_manifest.json"
const ROOM_PATHS := {
	"rooms": "res://scenes/rooms/Rooms/", "closed_doors": "res://scenes/rooms/Closed Doors/"
}


static func build_manifest() -> Dictionary:
	var manifest: Dictionary = {}
	for key in ROOM_PATHS.keys():
		manifest[key] = scan_folder(ROOM_PATHS[key])
	return manifest


static func scan_folder(path: String) -> Array:
	var files: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tscn"):
			files.append(path + file)
		file = dir.get_next()
	dir.list_dir_end()
	return files
