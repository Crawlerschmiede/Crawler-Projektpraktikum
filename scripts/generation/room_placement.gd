# gdlint: disable=max-public-methods
extends RefCounted
class_name RoomPlacer


# -----------------------------
# Stats object returned from generation
# -----------------------------
class GenStats:
	var rooms: int = 0
	var corridors: int = 0


# -----------------------------
# Small helpers
# -----------------------------
func get_room_key(scene: PackedScene) -> String:
	if scene == null:
		return ""
	return scene.resource_path


func get_rule(room_instance: Node, var_name: String, default_value):
	if room_instance == null:
		return default_value
	if var_name in room_instance:
		return room_instance.get(var_name)
	return default_value


func can_spawn_room(
	scene: PackedScene, room_instance: Node, placed_count: int, room_type_counts: Dictionary
) -> bool:
	var spawn_chance: float = float(get_rule(room_instance, "spawn_chance", 1.0))
	var max_count: int = int(get_rule(room_instance, "max_count", 999999))
	var min_rooms_before_spawn: int = int(get_rule(room_instance, "min_rooms_before_spawn", 0))

	if placed_count < min_rooms_before_spawn:
		return false

	var key := get_room_key(scene)
	var already := int(room_type_counts.get(key, 0))
	if already >= max_count:
		return false

	if spawn_chance < 1.0 and randf() > spawn_chance:
		return false

	return true


func is_corridor_room(room: Node) -> bool:
	if room == null:
		return false
	if not ("is_corridor" in room):
		return false

	var v = room.get("is_corridor")
	return typeof(v) == TYPE_BOOL and v


# -----------------------------
# Door matching
# -----------------------------
func find_matching_door(room: Node, from_direction: String):
	var opposite := {"north": "south", "south": "north", "east": "west", "west": "east"}
	if not opposite.has(from_direction):
		return null
	for d in room.get_free_doors():
		if d.direction == opposite[from_direction]:
			return d
	return null


# -----------------------------
# Collision (AABB rectangles from ALL CollisionShape2D)
# -----------------------------
class OverlapResult:
	var overlaps: bool = false
	var other_name: String = ""


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

			# CollisionShape2D kann verschoben sein
			var center := cs.global_position
			rects.append(Rect2(center - shape.extents, shape.extents * 2.0))

	return rects


func check_overlap_aabb(new_room: Node2D, against: Array[Node2D]) -> OverlapResult:
	var result := OverlapResult.new()

	var new_rects := _get_room_rects(new_room)
	if new_rects.is_empty():
		result.overlaps = true
		result.other_name = "missing_collision"
		return result

	for r in against:
		if r == null or r == new_room:
			continue

		var rects := _get_room_rects(r)
		if rects.is_empty():
			continue

		for a in new_rects:
			for b in rects:
				if a.intersects(b):
					result.overlaps = true
					result.other_name = r.name
					return result

	return result


# -----------------------------
# MAIN generation (best map build)
# -----------------------------
func generate_best(
	parent_node: Node,
	room_lib,
	start_room: PackedScene,
	max_rooms: int,
	genome,
	trial_seed: int,
	room_type_counts: Dictionary
) -> Array[Node2D]:
	await generate_with_genome(
		parent_node, room_lib, start_room, max_rooms, genome, trial_seed, true, room_type_counts
	)
	return _last_local_placed


# internal state output
var _last_local_placed: Array[Node2D] = []
var _last_corridor_count := 0


func generate_with_genome(
	parent_node: Node,
	room_lib,
	start_room: PackedScene,
	max_rooms: int,
	genome,
	trial_seed: int,
	verbose: bool,
	room_type_counts: Dictionary
) -> GenStats:
	seed(trial_seed)

	room_type_counts.clear()
	var stats := GenStats.new()

	var local_placed: Array[Node2D] = []
	var local_corridor_count := 0

	# ---------- START ROOM ----------
	var first_room := start_room.instantiate() as Node2D
	if first_room == null:
		if verbose:
			push_error("❌ [GEN] start_room.instantiate() ist kein Node2D")
		return stats

	parent_node.add_child(first_room)
	first_room.global_position = Vector2.ZERO
	first_room.add_to_group("room")

	first_room.set_meta("corridor_chain", 0)
	first_room.force_update_transform()

	local_placed.append(first_room)

	if not first_room.has_method("get_free_doors"):
		if verbose:
			push_error("❌ [ROOM] Start room hat kein get_free_doors()")
		return stats

	if is_corridor_room(first_room):
		local_corridor_count += 1

	var current_doors: Array = first_room.get_free_doors()
	var next_doors: Array = []

	# ---------- MAIN LOOP ----------
	while current_doors.size() > 0 and local_placed.size() < max_rooms:
		var door = current_doors.pop_front()
		if door == null or door.used:
			continue

		# door fill chance
		if float(genome.door_fill_chance) < 1.0 and randf() > float(genome.door_fill_chance):
			continue

		# Raum-Root finden
		var from_room: Node = door.get_parent()
		while from_room != null and not from_room.is_in_group("room"):
			from_room = from_room.get_parent()
		if from_room == null:
			if verbose:
				push_error("❌ [DOOR] Konnte Raum-Root nicht finden: " + str(door.name))
			continue

		var from_chain: int = int(from_room.get_meta("corridor_chain", 0))
		var from_corridor: bool = is_corridor_room(from_room)

		# Kandidaten in random order
		var candidates = room_lib.room_scenes.duplicate()
		candidates.shuffle()

		# corridor bias (optional)
		if abs(float(genome.corridor_bias) - 1.0) > 0.01:
			candidates.sort_custom(
				func(a: PackedScene, b: PackedScene) -> bool:
					var ca = room_lib.is_corridor(a)
					var cb = room_lib.is_corridor(b)
					if float(genome.corridor_bias) > 1.0:
						return int(ca) > int(cb)  # corridors first
					return int(ca) < int(cb)  # corridors last
			)

		var placed := false

		for room_scene in candidates:
			if room_scene == null:
				continue

			var new_room := room_scene.instantiate() as Node2D
			if new_room == null:
				continue

			# spawn rules
			if not can_spawn_room(room_scene, new_room, local_placed.size(), room_type_counts):
				new_room.queue_free()
				continue

			if not new_room.has_method("get_free_doors"):
				new_room.queue_free()
				continue

			var to_corridor := is_corridor_room(new_room)

			# ---------- Corridor rules ----------
			if to_corridor:
				if local_corridor_count >= int(genome.max_corridors):
					new_room.queue_free()
					continue

				var new_chain := from_chain + 1
				if new_chain > int(genome.max_corridor_chain):
					new_room.queue_free()
					continue

			# if chain full -> forbid corridor placements
			if from_corridor and from_chain >= int(genome.max_corridor_chain):
				if to_corridor:
					new_room.queue_free()
					continue

			# match doors
			var matching_door = find_matching_door(new_room, door.direction)
			if matching_door == null:
				new_room.queue_free()
				continue

			# add to tree before reading globals
			parent_node.add_child(new_room)
			new_room.add_to_group("room")

			# SNAP like you did
			var offset: Vector2 = matching_door.global_position - new_room.global_position
			new_room.global_position = door.global_position - offset
			new_room.force_update_transform()

			# OVERLAP
			var overlap := check_overlap_aabb(new_room, local_placed)
			if overlap.overlaps:
				new_room.queue_free()
				continue

			# SUCCESS
			door.used = true
			matching_door.used = true

			# corridor chain meta
			if to_corridor:
				local_corridor_count += 1
				new_room.set_meta("corridor_chain", from_chain + 1)
			else:
				new_room.set_meta("corridor_chain", 0)

			# store tile_origin meta for baking later
			var room_tm := new_room.get_node_or_null("TileMapLayer") as TileMapLayer
			if room_tm != null:
				var tile_size := room_tm.tile_set.tile_size
				var tile_origin := Vector2i(
					int(round(new_room.global_position.x / tile_size.x)),
					int(round(new_room.global_position.y / tile_size.y))
				)
				new_room.set_meta("tile_origin", tile_origin)

			# increment type count
			var key := get_room_key(room_scene)
			room_type_counts[key] = int(room_type_counts.get(key, 0)) + 1

			# update lists
			local_placed.append(new_room)
			next_doors += new_room.get_free_doors()

			placed = true
			break

		# if no placement found -> door stays open

		# door batch switch
		if current_doors.is_empty():
			current_doors = next_doors
			next_doors = []

	# stats
	stats.rooms = local_placed.size()
	stats.corridors = local_corridor_count

	_last_local_placed = local_placed
	_last_corridor_count = local_corridor_count

	return stats
