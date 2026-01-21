extends RefCounted
class_name RoomPlacer


class GenStats:
	var rooms: int = 0
	var corridors: int = 0


# ✅ nur für GA: generiert in parent_node und gibt stats zurück
func generate_stats(
	parent_node: Node,
	lib: RoomLibrary,
	start_room: PackedScene,
	max_rooms: int,
	genome,
	trial_seed: int
) -> GenStats:
	var stats := GenStats.new()

	seed(trial_seed)

	var placed: Array[Node2D] = []
	var corridor_count := 0

	# --- start room
	var first := start_room.instantiate() as Node2D
	parent_node.add_child(first)
	first.global_position = Vector2.ZERO
	first.add_to_group("room")
	first.set_meta("corridor_chain", 0)
	first.force_update_transform()
	placed.append(first)

	if _is_corridor(first):
		corridor_count += 1

	var current_doors: Array = first.get_free_doors()
	var next_doors: Array = []

	while current_doors.size() > 0 and placed.size() < max_rooms:
		var door = current_doors.pop_front()
		if door == null or door.used:
			continue

		if randf() > float(genome.door_fill_chance):
			continue

		var from_room := _find_room_root(door)
		if from_room == null:
			continue

		var from_chain := int(from_room.get_meta("corridor_chain", 0))
		var from_corridor := _is_corridor(from_room)

		var candidates := lib.room_scenes.duplicate()
		candidates.shuffle()

		var placed_room := false

		for scene in candidates:
			var new_room := scene.instantiate() as Node2D
			if new_room == null:
				continue

			if not new_room.has_method("get_free_doors"):
				new_room.queue_free()
				continue

			var to_corridor := _is_corridor(new_room)

			# corridor limits
			if to_corridor:
				if corridor_count >= int(genome.max_corridors):
					new_room.queue_free()
					continue
				if from_chain + 1 > int(genome.max_corridor_chain):
					new_room.queue_free()
					continue

			if from_corridor and from_chain >= int(genome.max_corridor_chain) and to_corridor:
				new_room.queue_free()
				continue

			var matching = _find_matching_door(new_room, door.direction)
			if matching == null:
				new_room.queue_free()
				continue

			parent_node.add_child(new_room)
			new_room.add_to_group("room")

			# snap
			var offset = matching.global_position - new_room.global_position
			new_room.global_position = door.global_position - offset
			new_room.force_update_transform()

			# ✅ overlap check über Library/Placer
			if _check_overlap(new_room, placed):
				new_room.queue_free()
				continue

			# success
			door.used = true
			matching.used = true

			if to_corridor:
				corridor_count += 1
				new_room.set_meta("corridor_chain", from_chain + 1)
			else:
				new_room.set_meta("corridor_chain", 0)

			# tile_origin
			var room_tm := new_room.get_node_or_null("TileMapLayer") as TileMapLayer
			if room_tm:
				var ts := room_tm.tile_set.tile_size
				var origin := Vector2i(
					int(round(new_room.global_position.x / ts.x)),
					int(round(new_room.global_position.y / ts.y))
				)
				new_room.set_meta("tile_origin", origin)

			placed.append(new_room)
			next_doors += new_room.get_free_doors()
			placed_room = true
			break

		if not placed_room:
			pass

		if current_doors.is_empty():
			current_doors = next_doors
			next_doors = []

	stats.rooms = placed.size()
	stats.corridors = corridor_count
	return stats


func _get_room_rects(room: Node2D) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var area := room.get_node_or_null("Area2D") as Area2D
	if area == null:
		return rects

	for child in area.get_children():
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			var shape := cs.shape as RectangleShape2D
			if shape == null:
				continue
			var center := cs.global_position
			rects.append(Rect2(center - shape.extents, shape.extents * 2.0))

	return rects


func _check_overlap(new_room: Node2D, against: Array[Node2D]) -> bool:
	var new_rects := _get_room_rects(new_room)
	if new_rects.is_empty():
		return true  # wenn kein collision shape -> blocken

	for other in against:
		if other == null or other == new_room:
			continue

		var other_rects := _get_room_rects(other)
		for a in new_rects:
			for b in other_rects:
				if a.intersects(b):
					return true

	return false


# echte Map bauen (für DungeonGenerator)
func generate_best(
	parent_node: Node,
	lib: RoomLibrary,
	start_room: PackedScene,
	max_rooms: int,
	genome,
	trial_seed: int,
	room_type_counts: Dictionary
) -> Array[Node2D]:
	# gleiche Logik wie generate_stats
	# nur: du gibst am Ende placed zurück und füllst room_type_counts
	var stats := await generate_stats(parent_node, lib, start_room, max_rooms, genome, trial_seed)
	# ⚠️ generate_stats hat intern placed lokal -> daher hier nochmal separat implementieren,
	# oder du baust generate_stats um dass es placed zurückgeben kann.
	# -> ich würde lieber Funktion splitten in _generate_internal(return_rooms, return_stats)
	return []


# -------------------
# helpers
# -------------------
func _find_room_root(node: Node) -> Node:
	var r := node.get_parent()
	while r != null and not r.is_in_group("room"):
		r = r.get_parent()
	return r


func _is_corridor(room: Node) -> bool:
	return ("is_corridor" in room) and bool(room.get("is_corridor"))


func _find_matching_door(room: Node, from_dir: String):
	var opposite := {"north": "south", "south": "north", "east": "west", "west": "east"}
	if not opposite.has(from_dir):
		return null
	for d in room.get_free_doors():
		if d.direction == opposite[from_dir]:
			return d
	return null
