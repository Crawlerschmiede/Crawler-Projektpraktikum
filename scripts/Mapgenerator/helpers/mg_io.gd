# IO- und Szenen-Hilfen

class_name MGIOModule

const ROOM_MANIFEST_PATH := "res://scenes/rooms/room_manifest.json"
const ManifestUtils = preload("res://scripts/Mapgenerator/helpers/room_manifest_utils.gd")


func load_room_scenes_from_folder(path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Folder not found: " + path)
		result = _load_room_scenes_from_manifest(path)
	else:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if not dir.current_is_dir():
				if file.ends_with(".tscn"):
					var full_path := path + file
					var ps := load(full_path)
					if ps is PackedScene:
						result.append(ps)
					else:
						push_warning("Not a PackedScene: " + full_path)
			file = dir.get_next()
		dir.list_dir_end()
		if result.is_empty():
			if Engine.is_editor_hint():
				push_warning("No room scenes found in folder: " + path)
			else:
				result = _load_room_scenes_from_manifest(path)
	return result


func _load_room_scenes_from_manifest(path: String) -> Array:
	var result: Array = []
	var f := FileAccess.open(ROOM_MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return result
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Room manifest has invalid format: " + ROOM_MANIFEST_PATH)
		return result
	var manifest: Dictionary = parsed
	var key := _get_manifest_key_for_path(path)
	if key == "":
		push_warning("No manifest key matches path: " + path)
		return result
	var items = manifest.get(key)
	if typeof(items) != TYPE_ARRAY:
		return result
	for p in items:
		if typeof(p) != TYPE_STRING:
			continue
		var pstr: String = p
		if not pstr.begins_with(path):
			continue
		var ps := load(pstr)
		if ps is PackedScene:
			result.append(ps)
		else:
			push_warning("Not a PackedScene: " + pstr)
	return result


func _get_manifest_key_for_path(path: String) -> String:
	for k in ManifestUtils.ROOM_PATHS.keys():
		var base_path = str(ManifestUtils.ROOM_PATHS[k])
		if path.begins_with(base_path):
			return str(k)
	return ""


func _get_closed_door_direction(scene: PackedScene) -> String:
	if scene == null:
		return ""
	var key := scene.resource_path
	# caller is responsible for caching if desired
	var inst := scene.instantiate()
	var dir := ""
	if inst != null:
		if "direction" in inst:
			dir = str(inst.get("direction")).to_lower()
		elif inst.has_node("Doors"):
			var doors_node := inst.get_node("Doors")
			for d in doors_node.get_children():
				if d != null and "direction" in d:
					dir = str(d.get("direction")).to_lower()
					break
		inst.queue_free()
	return dir


func get_room_key(scene: PackedScene) -> String:
	if scene == null:
		return ""
	var key = scene.resource_path
	var inst := scene.instantiate()
	if inst != null and inst.get_groups():
		key = inst.get_groups()[0]
		inst.queue_free()
	return key


func load_closed_door_scenes_from_folder(path: String) -> Array:
	return load_room_scenes_from_folder(path)


func clear_children_rooms_only(gen) -> void:
	for c in gen.get_children():
		if c == null:
			continue
		c.queue_free()
	gen.placed_rooms.clear()
	gen.corridor_count = 0


func clear_world_tilemaps(gen) -> void:
	if gen.world_tilemap != null and is_instance_valid(gen.world_tilemap):
		gen.world_tilemap.queue_free()
	gen.world_tilemap = null
	if gen.world_tilemap_top != null and is_instance_valid(gen.world_tilemap_top):
		gen.world_tilemap_top.queue_free()
	gen.world_tilemap_top = null


func get_main_tilemap(gen) -> TileMapLayer:
	for room in gen.placed_rooms:
		if room.has_node("TileMapLayer"):
			return room.get_node("TileMapLayer")
	return null


func get_required_scenes(gen) -> Array:
	var required: Array = []
	for s in gen.room_scenes:
		if s == null:
			continue
		var inst = s.instantiate()
		if inst == null:
			continue
		if "required_min_count" in inst:
			var req := int(inst.get("required_min_count"))
			if req > 0:
				required.append(s)
		inst.queue_free()
	if gen.boss_room != null:
		var b = gen.boss_room.instantiate()
		if b != null and "required_min_count" in b and int(b.get("required_min_count")) > 0:
			required.append(gen.boss_room)
		if b != null:
			b.queue_free()
	return required
