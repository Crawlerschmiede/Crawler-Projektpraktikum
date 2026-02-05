# Generierungs-Logik (Platzieren von Räumen)

class_name MGGeneration

const MGCOL = preload("res://scenes/testscene2/mg_collision.gd")
const MGIO = preload("res://scenes/testscene2/mg_io.gd")
const MGGENOME = preload("res://scenes/testscene2/mg_genome.gd")

# module instances to call non-static functions
var mg_coll = MGCOL.new()
var mg_io = MGIO.new()


func can_spawn_room(gen, scene: PackedScene, room_instance: Node, placed_count: int) -> bool:
	var spawn_chance: float = float(get_rule(room_instance, "spawn_chance", 1.0))
	var max_count: int = int(get_rule(room_instance, "max_count", 999999))
	var min_rooms_before_spawn: int = int(get_rule(room_instance, "min_rooms_before_spawn", 0))
	if placed_count < min_rooms_before_spawn:
		return false
	var key = mg_io.get_room_key(scene)
	var already = int(gen.room_type_counts.get(key, 0))
	if already >= max_count:
		return false
	if spawn_chance < 1.0 and gen._rng.randf() > spawn_chance:
		return false
	return true


func get_rule(room_instance: Node, var_name: String, default_value):
	if room_instance == null:
		return default_value
	if var_name in room_instance:
		return room_instance.get(var_name)
	return default_value


func ensure_required_rooms(gen, parent_node: Node, local_placed: Array, genome) -> void:
	var required_scenes = mg_io.get_required_scenes(gen)
	if required_scenes.is_empty():
		return
	var free_doors: Array = []
	for r in local_placed:
		if r != null and r.has_method("get_free_doors"):
			for d in r.get_free_doors():
				if d != null and not d.used:
					free_doors.append(d)
	GlobalRNG.shuffle_array(free_doors, gen._rng)
	for scene in required_scenes:
		var key = mg_io.get_room_key(scene)
		var temp = scene.instantiate()
		if temp == null:
			continue
		var required_min = int(get_rule(temp, "required_min_count", 0))
		temp.queue_free()
		var current = int(gen.room_type_counts.get(key, 0))
		while current < required_min and free_doors.size() > 0:
			var door = free_doors.pop_front()
			if door == null or door.used:
				continue
			var res = try_place_specific_room(gen, scene, door, parent_node, local_placed, genome)
			if res:
				current += 1
				gen.room_type_counts[key] = current


func try_place_specific_room(
	gen, scene: PackedScene, door, parent_node: Node, local_placed: Array, _genome
) -> bool:
	if scene == null:
		return false
	var new_room = scene.instantiate() as Node2D
	if new_room == null or not new_room.has_method("get_free_doors"):
		if new_room != null:
			new_room.queue_free()
		return false
	if not can_spawn_room(gen, scene, new_room, local_placed.size()):
		new_room.queue_free()
		return false
	var matching_door = mg_coll.find_matching_door(gen, new_room, door.direction)
	if matching_door == null:
		new_room.queue_free()
		return false
	parent_node.add_child(new_room)
	new_room.add_to_group("room")
	var offset: Vector2 = matching_door.global_position - new_room.global_position
	new_room.global_position = door.global_position - offset
	new_room.force_update_transform()
	var overlap = mg_coll.check_overlap_aabb(new_room, local_placed)
	if overlap.overlaps:
		new_room.queue_free()
		return false
	door.used = true
	matching_door.used = true
	var from_room: Node = door.get_parent()
	while from_room != null and not from_room.is_in_group("room"):
		from_room = from_room.get_parent()
	var from_chain: int = int(from_room.get_meta("corridor_chain", 0)) if from_room != null else 0
	if mg_coll.is_corridor_room(gen, new_room):
		new_room.set_meta("corridor_chain", from_chain + 1)
	else:
		new_room.set_meta("corridor_chain", 0)
	var room_tm = new_room.get_node_or_null("TileMapLayer") as TileMapLayer
	if room_tm:
		var tile_size = room_tm.tile_set.tile_size
		var tile_origin = Vector2i(
			int(round(new_room.global_position.x / tile_size.x)),
			int(round(new_room.global_position.y / tile_size.y))
		)
		new_room.set_meta("tile_origin", tile_origin)
	local_placed.append(new_room)
	return true


func generate_with_genome(
	gen, genome, trial_seed: int, verbose: bool, parent_override: Node = null
):
	# Diese Funktion nutzt viele gen.-Felder und ist bewusst kompakt gehalten.
	gen._rng.seed = int(trial_seed)
	gen.room_type_counts.clear()
	var stats = MGGENOME.GenStats.new()
	var local_placed: Array = []
	var local_corridor_count = 0
	var parent_node: Node = parent_override if parent_override != null else gen
	var first_room = gen.start_room.instantiate() as Node2D
	if first_room == null:
		if verbose:
			push_error("❌ [GEN] start_room.instantiate() ist kein Node2D")
		return stats
	parent_node.add_child(first_room)
	first_room.global_position = Vector2.ZERO
	first_room.add_to_group("room")
	gen._emit_progress_mapped(0.45, 0.75, 0.0, "Placing rooms...")
	await gen.get_tree().process_frame
	first_room.set_meta("corridor_chain", 0)
	first_room.force_update_transform()
	local_placed.append(first_room)
	if not first_room.has_method("get_free_doors"):
		if verbose:
			push_error("❌ [ROOM] Start room hat kein get_free_doors()")
		return stats
	if mg_coll.is_corridor_room(gen, first_room):
		local_corridor_count += 1
	var current_doors: Array = first_room.get_free_doors()
	var next_doors: Array = []
	var loop_iter = 0
	while current_doors.size() > 0 and local_placed.size() < gen.max_rooms:
		if loop_iter % 5 == 0:
			var local_p = 0.0
			if gen.max_rooms > 0:
				local_p = float(local_placed.size()) / float(gen.max_rooms)
			gen._emit_progress_mapped(
				0.45,
				0.75,
				clamp(local_p, 0.0, 1.0),
				"Placing rooms: %d/%d" % [local_placed.size(), gen.max_rooms]
			)
			await gen.get_tree().process_frame
		var door = current_doors.pop_front()
		if door == null or door.used:
			continue
		loop_iter += 1
		if loop_iter % gen.yield_frame_chunk == 0:
			await gen._yield_if_needed(1)
		if genome.door_fill_chance < 1.0 and gen._rng.randf() > genome.door_fill_chance:
			continue
		var from_room: Node = door.get_parent()
		while from_room != null and not from_room.is_in_group("room"):
			from_room = from_room.get_parent()
		if from_room == null:
			if verbose:
				push_error("❌ [DOOR] Konnte Raum-Root nicht finden für Door: " + str(door.name))
			continue
		var from_chain: int = int(from_room.get_meta("corridor_chain", 0))
		var from_corridor: bool = mg_coll.is_corridor_room(gen, from_room)
		var candidates = gen.room_scenes.duplicate()
		GlobalRNG.shuffle_array(candidates, gen._rng)
		if abs(genome.corridor_bias - 1.0) > 0.01:
			candidates.sort_custom(
				func(a, b) -> bool:
					return (
						(
							int(mg_coll._scene_is_corridor(gen, a))
							> int(mg_coll._scene_is_corridor(gen, b))
						)
						if genome.corridor_bias > 1.0
						else (
							int(mg_coll._scene_is_corridor(gen, a))
							< int(mg_coll._scene_is_corridor(gen, b))
						)
					)
			)
		var placed = false
		for room_scene in candidates:
			if room_scene == null:
				continue
			if gen._yield_counter % gen.yield_frame_chunk == 0:
				await gen._yield_if_needed(1)
			var new_room = room_scene.instantiate() as Node2D
			if not can_spawn_room(gen, room_scene, new_room, local_placed.size()):
				if new_room != null:
					new_room.queue_free()
				continue
			if new_room == null or not new_room.has_method("get_free_doors"):
				if new_room != null:
					new_room.queue_free()
				continue
			var to_corridor = mg_coll.is_corridor_room(gen, new_room)
			if to_corridor:
				if local_corridor_count >= genome.max_corridors:
					new_room.queue_free()
					continue
				var new_chain = from_chain + 1
				if new_chain > genome.max_corridor_chain:
					new_room.queue_free()
					continue
			if (
				from_corridor
				and from_chain >= genome.max_corridor_chain
				and mg_coll.is_corridor_room(gen, new_room)
			):
				new_room.queue_free()
				continue
			var matching_door = mg_coll.find_matching_door(gen, new_room, door.direction)
			if matching_door == null:
				new_room.queue_free()
				continue
			parent_node.add_child(new_room)
			new_room.add_to_group("room")
			var offset: Vector2 = matching_door.global_position - new_room.global_position
			new_room.global_position = door.global_position - offset
			new_room.force_update_transform()
			var overlap = mg_coll.check_overlap_aabb(new_room, local_placed)
			if overlap.overlaps:
				new_room.queue_free()
				continue
			door.used = true
			matching_door.used = true
			if mg_coll.is_corridor_room(gen, new_room):
				local_corridor_count += 1
				new_room.set_meta("corridor_chain", from_chain + 1)
			else:
				new_room.set_meta("corridor_chain", 0)
			var room_tm = new_room.get_node_or_null("TileMapLayer") as TileMapLayer
			if room_tm:
				var tile_size = room_tm.tile_set.tile_size
				var tile_origin = Vector2i(
					int(round(new_room.global_position.x / tile_size.x)),
					int(round(new_room.global_position.y / tile_size.y))
				)
				new_room.set_meta("tile_origin", tile_origin)
			local_placed.append(new_room)
			next_doors += new_room.get_free_doors()
			var key = mg_io.get_room_key(room_scene)
			gen.room_type_counts[key] = int(gen.room_type_counts.get(key, 0)) + 1
			placed = true
			break
		if not placed:
			pass
		if current_doors.is_empty():
			current_doors = next_doors
			next_doors = []
	stats.rooms = local_placed.size()
	stats.corridors = local_corridor_count
	gen._emit_progress_mapped(0.45, 0.75, 1.0, "Rooms placed: %d" % stats.rooms)
	await gen.get_tree().process_frame
	if parent_override == null:
		gen.placed_rooms = local_placed
		gen.corridor_count = local_corridor_count
	ensure_required_rooms(gen, parent_node, local_placed, genome)
	return stats
