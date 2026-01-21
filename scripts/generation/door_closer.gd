extends RefCounted
class_name DoorCloser

var closed_door_scenes: Array[PackedScene] = []
var door_dir_cache := {}


func load_closed_doors(path: String, lib: RoomLibrary) -> void:
	closed_door_scenes = lib._load_scenes_from_folder(path)


func get_scene_direction(scene: PackedScene) -> String:
	if scene == null:
		return ""

	var key := scene.resource_path
	if door_dir_cache.has(key):
		return door_dir_cache[key]

	var inst := scene.instantiate()
	var dir := ""

	if inst != null:
		if "direction" in inst:
			dir = str(inst.get("direction")).to_lower()
		elif inst.has_node("Doors"):
			for d in inst.get_node("Doors").get_children():
				if d != null and "direction" in d:
					dir = str(d.get("direction")).to_lower()
					break
		inst.queue_free()

	door_dir_cache[key] = dir
	return dir


func get_closed_door_for_direction(dir: String) -> PackedScene:
	dir = dir.to_lower()
	var candidates: Array[PackedScene] = []
	for s in closed_door_scenes:
		if get_scene_direction(s) == dir:
			candidates.append(s)

	return null if candidates.is_empty() else candidates.pick_random()


func bake_closed_doors(generator: Node, placed_rooms: Array[Node2D], baker: WorldBaker) -> void:
	var total := 0

	for room in placed_rooms:
		if room == null or not room.has_method("get_free_doors"):
			continue

		for door in room.get_free_doors():
			if door == null or door.used:
				continue

			var scene := get_closed_door_for_direction(str(door.direction))
			if scene == null:
				continue

			total += baker.bake_closed_door_scene(
				generator, scene, door.global_position, door.global_rotation
			)
			door.used = true

	print("✔ [BAKE] Closed Doors:", total)
