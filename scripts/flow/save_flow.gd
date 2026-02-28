extends RefCounted

const SAVE_PATH := "user://world_tilemap_save.json"


func build_save_payload(
	world_index: int,
	floor_data: Dictionary,
	top_data: Dictionary,
	entities_data: Array,
	minimap_data: Dictionary,
	selected_skills: Array
) -> Dictionary:
	return {
		"world_index": world_index,
		"floor": floor_data,
		"top": top_data,
		"entities": entities_data,
		"minimap": minimap_data,
		"selected_skills": selected_skills,
	}


func write_payload(payload: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveFlow.write_payload: failed to open " + SAVE_PATH)
		return false

	file.store_string(JSON.stringify(payload, "  ", false))
	file.close()
	return true


func read_payload() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		push_error("SaveFlow.read_payload: save file not found: " + SAVE_PATH)
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveFlow.read_payload: failed to open " + SAVE_PATH)
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveFlow.read_payload: failed to parse save JSON")
		return {}

	return parsed


func build_loaded_world_result(
	payload: Dictionary,
	default_world_index: int,
	deserialize_tilemap_callable: Callable,
	deserialize_minimap_callable: Callable
) -> Dictionary:
	if not deserialize_tilemap_callable.is_valid():
		push_warning("SaveFlow: deserialize_tilemap_callable is invalid")
		return {}
	if not deserialize_minimap_callable.is_valid():
		push_warning("SaveFlow: deserialize_minimap_callable is invalid")
		return {}

	var result: Dictionary = {}
	result["world_index"] = int(payload.get("world_index", default_world_index))

	var floor_data: Dictionary = payload.get("floor", {})
	var top_data: Dictionary = payload.get("top", {})
	var entities_data: Array = payload.get("entities", [])

	result["floor"] = deserialize_tilemap_callable.call(floor_data)
	result["top"] = deserialize_tilemap_callable.call(top_data)
	result["entities"] = entities_data

	var minimap_node = null
	var minimap_data: Variant = payload.get("minimap", {})
	if typeof(minimap_data) == TYPE_DICTIONARY and not minimap_data.is_empty():
		minimap_node = deserialize_minimap_callable.call(minimap_data)
	result["minimap"] = minimap_node

	result["selected_skills"] = payload.get("selected_skills", [])
	return result
