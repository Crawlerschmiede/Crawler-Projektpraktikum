extends Node2D

@export var room_count: int = 3000
@export var start_position: Vector2 = Vector2(500, 500)
@export var rooms_available: int = 5
@export var ga_iterations: int = 500

const CELL_SIZE: float = 256.0

var used_doors: Array[Marker2D] = []
var open_doors: Array[Marker2D] = []
var room_scenes: Array[PackedScene] = []
var room_defs: Array[Dictionary] = []  # {"scene":PackedScene, "doors":Array[Dictionary], "rect":Rect2}


func _ready() -> void:
	randomize()
	_load_room_scenes()
	if room_defs.is_empty():
		push_error("Keine Room-Szenen gefunden!")
		return

	_run_simple_ga()


# -------------------------------------------------------------------
# ROOM SCENE LOADING + CACHING
# -------------------------------------------------------------------


func _load_room_scenes() -> void:
	room_scenes.clear()
	room_defs.clear()

	for i in range(1, rooms_available + 1):
		var path: String = "res://scenes/Room%d.tscn" % i

		if not ResourceLoader.exists(path):
			push_warning("Fehlt: " + path)
			continue

		var sc: Resource = load(path)
		if not (sc is PackedScene):
			push_warning("Ungültige Scene: " + path)
			continue

		var scene: PackedScene = sc
		room_scenes.append(scene)

		# Room instanzieren, um Türen & AABB auszulesen
		var temp: Node2D = scene.instantiate() as Node2D
		if temp == null:
			push_warning("Scene ist kein Node2D: " + path)
			continue

		var doors_local: Array[Dictionary] = []
		for c in temp.get_children():
			if c is Marker2D and c.name.begins_with("Door"):
				var marker := c as Marker2D
				doors_local.append({"pos": marker.position, "rot": marker.rotation})

		var local_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(128, 128))

		var area: Area2D = temp.get_node_or_null("Area2D")
		if area == null:
			var found := temp.find_child("Area2D", true, false)
			if found is Area2D:
				area = found

		if area:
			var cs := area.get_child(0) as CollisionShape2D
			if cs and cs.shape and cs.shape.has_method("get_rect"):
				local_rect = cs.shape.get_rect()

		room_defs.append({"scene": scene, "doors": doors_local, "rect": local_rect})

		temp.queue_free()


# -------------------------------------------------------------------
# SPATIAL HASH
# -------------------------------------------------------------------


func _rect_to_global_aabb(local_rect: Rect2, room_pos: Vector2, room_rot: float) -> Rect2:
	var corners: Array[Vector2] = [
		local_rect.position,
		local_rect.position + Vector2(local_rect.size.x, 0.0),
		local_rect.position + Vector2(0.0, local_rect.size.y),
		local_rect.position + local_rect.size
	]

	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF

	for c: Vector2 in corners:
		var g: Vector2 = c.rotated(room_rot) + room_pos
		min_x = min(min_x, g.x)
		min_y = min(min_y, g.y)
		max_x = max(max_x, g.x)
		max_y = max(max_y, g.y)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _cell_from_point(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL_SIZE)), int(floor(p.y / CELL_SIZE)))


func _grid_register_room(aabb: Rect2, grid: Dictionary) -> void:
	var min_cell: Vector2i = _cell_from_point(aabb.position)
	var max_cell: Vector2i = _cell_from_point(aabb.position + aabb.size)

	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				grid[cell] = []
			(grid[cell] as Array).append(aabb)


func _room_overlaps_grid(aabb: Rect2, grid: Dictionary) -> bool:
	if grid.is_empty():
		return false

	var min_cell: Vector2i = _cell_from_point(aabb.position)
	var max_cell: Vector2i = _cell_from_point(aabb.position + aabb.size)

	for x in range(min_cell.x - 1, max_cell.x + 2):
		for y in range(min_cell.y - 1, max_cell.y + 2):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue

			var list: Array = grid[cell]
			for other_aabb: Rect2 in list:
				if aabb.intersects(other_aabb):
					return true

	return false


# -------------------------------------------------------------------
# ROOM HELPERS
# -------------------------------------------------------------------


func _clear_rooms() -> void:
	for r in get_tree().get_nodes_in_group("rooms"):
		r.queue_free()

	used_doors.clear()
	open_doors.clear()


func get_doors(room: Node2D) -> Array[Marker2D]:
	var arr: Array[Marker2D] = []
	for c in room.get_children():
		if c is Marker2D and c.name.begins_with("Door"):
			arr.append(c as Marker2D)
	return arr


# -------------------------------------------------------------------
# GENOME
# -------------------------------------------------------------------


func create_genome() -> Array[int]:
	var g: Array[int] = []
	var weighted: Array[int] = [1, 2, 4, 4, 4, 3, 3, 3, 3, 5, 5, 5, 5]

	for i in range(room_count):
		g.append(weighted[randi_range(0, weighted.size() - 1)])

	return g


# -------------------------------------------------------------------
# FITNESS
# -------------------------------------------------------------------


func compute_fitness(stats: Dictionary) -> float:
	var p: int = stats["placed_rooms"]
	var s: int = stats["room_score"]
	var o: int = stats["open_doors"]

	var f: float = 0.0
	f += s * 8.0
	f += p * 12.0
	f += sqrt(float(p)) * 25.0

	if p > 0:
		f -= float(o) / float(p) * 30.0

	if s > p * 2:
		f += s * 5.0

	return f


# -------------------------------------------------------------------
# DUNGEON GENERATION (Optimiert + Typisiert)
# -------------------------------------------------------------------


func generate_from_genome(genome: Array[int]) -> Dictionary:
	used_doors.clear()
	open_doors.clear()

	var stats: Dictionary = {"room_score": 0, "open_doors": 0, "placed_rooms": 0}

	var grid: Dictionary = {}

	# -------- erster Raum --------
	var type0: int = clamp(genome[0], 1, rooms_available)
	var rdef: Dictionary = room_defs[type0 - 1]
	var rect0: Rect2 = rdef["rect"]

	var pos0: Vector2 = start_position
	var rot0: float = 0.0

	var aabb0 := _rect_to_global_aabb(rect0, pos0, rot0)
	_grid_register_room(aabb0, grid)

	var room0: Node2D = (rdef["scene"] as PackedScene).instantiate()
	add_child(room0)
	room0.add_to_group("rooms")
	room0.global_position = pos0
	room0.rotation = rot0

	stats["placed_rooms"] += 1
	stats["room_score"] += (10 if type0 in [3, 5] else 1)

	open_doors.append_array(get_doors(room0))

	# -------- weitere Räume --------
	for i in range(1, genome.size()):
		if open_doors.is_empty():
			break

		var prev: Marker2D = open_doors.pop_front()
		if not is_instance_valid(prev):
			continue

		var placed := false
		var gene_type: float = clamp(genome[i], 1, rooms_available)

		for attempt in range(50):
			var try_type: int = gene_type if attempt == 0 else randi_range(1, rooms_available)
			var def := room_defs[try_type - 1]

			var doors_template: Array[Dictionary] = def["doors"]
			if doors_template.is_empty():
				continue

			var indices: Array[int] = []
			for idx in range(doors_template.size()):
				indices.append(idx)
			indices.shuffle()

			for idx in indices:
				var dtemp: Dictionary = doors_template[idx]
				var door_pos: Vector2 = dtemp["pos"]
				var door_rot: float = dtemp["rot"]

				var target_rot := prev.global_rotation + PI
				var new_rot := target_rot - door_rot
				var rotated_door_pos := door_pos.rotated(new_rot)
				var new_pos := prev.global_position - rotated_door_pos

				var rect_local: Rect2 = def["rect"]
				var test_aabb := _rect_to_global_aabb(rect_local, new_pos, new_rot)

				if _room_overlaps_grid(test_aabb, grid):
					continue

				var new_room: Node2D = (def["scene"] as PackedScene).instantiate()
				add_child(new_room)
				new_room.add_to_group("rooms")
				new_room.global_position = new_pos
				new_room.rotation = new_rot

				_grid_register_room(test_aabb, grid)

				placed = true
				stats["placed_rooms"] += 1
				stats["room_score"] += (10 if try_type in [3, 5] else 1)

				var room_doors := get_doors(new_room)
				var used_door: Marker2D = null
				var min_dist := INF

				for d in room_doors:
					var dist := d.global_position.distance_to(prev.global_position)
					if dist < min_dist:
						min_dist = dist
						used_door = d

				for d in room_doors:
					if d != used_door:
						open_doors.append(d)

				used_doors.append(prev)
				if used_door:
					used_doors.append(used_door)

				break

			if placed:
				break

		if not placed:
			continue

	stats["open_doors"] = open_doors.size()
	return stats


# -------------------------------------------------------------------
# GENETIC SEARCH
# -------------------------------------------------------------------


func _run_simple_ga() -> void:
	var best_genome: Array[int] = []
	var best_fitness: float = -INF

	for i in range(ga_iterations):
		var genome: Array[int] = create_genome()
		_clear_rooms()

		var stats: Dictionary = generate_from_genome(genome)
		var fitness := compute_fitness(stats)

		print("Layout ", i, " -> Fitness =", fitness, " | ", stats)

		if fitness > best_fitness:
			best_fitness = fitness
			best_genome = genome.duplicate()

	_clear_rooms()
	var final_stats := generate_from_genome(best_genome)

	print("\nBESTES GENOM =", best_genome)
	print("BESTE FITNESS =", best_fitness)
