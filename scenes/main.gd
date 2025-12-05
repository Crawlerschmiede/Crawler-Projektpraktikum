extends Node2D

@export var room_count: int = 3000
@export var start_position: Vector2 = Vector2(500, 500)
@export var rooms_available: int = 5

var used_doors: Array[Marker2D] = []
var open_doors: Array[Marker2D] = []
var room_scenes: Array[PackedScene] = []


func _ready() -> void:
	randomize()
	_load_room_scenes()
	if room_scenes.is_empty():
		push_error("Keine Room-Szenen gefunden!")
		return
	_run_simple_ga()


# -------------------------------------------------------------------
# Hilfsfunktionen
# -------------------------------------------------------------------

func _load_room_scenes() -> void:
	room_scenes.clear()
	for i in range(1, rooms_available + 1):
		var path = "res://scenes/Room%d.tscn" % i
		if ResourceLoader.exists(path):
			var sc = load(path)
			if sc is PackedScene:
				room_scenes.append(sc)
			else:
				push_warning("Ungültige Scene: " + path)
		else:
			push_warning("Fehlt: " + path)


func _clear_rooms() -> void:
	for r in get_tree().get_nodes_in_group("rooms"):
		r.queue_free()


func get_doors(room: Node2D) -> Array[Marker2D]:
	var arr: Array[Marker2D] = []
	for c in room.get_children():
		if c is Marker2D and c.name.begins_with("Door"):
			arr.append(c)
	return arr


func get_room_area(room: Node) -> Area2D:
	var a = room.get_node_or_null("Area2D")
	if a: return a
	var found: Node = room.find_child("Area2D", true, false)
	if found is Area2D: return found
	return null


func get_room_aabb(room: Node2D) -> Rect2:
	var area: Area2D = get_room_area(room)
	if area == null:
		return Rect2(room.global_position, Vector2(128,128))
	var rect: Rect2 = (area.get_child(0) as CollisionShape2D).shape.get_rect()
	return Rect2(room.global_position + rect.position, rect.size)


func room_overlaps(room: Node2D) -> bool:
	var aabb = get_room_aabb(room)
	for other in get_tree().get_nodes_in_group("rooms"):
		if other == room: continue
		if aabb.intersects(get_room_aabb(other)):
			return true
	return false


# -------------------------------------------------------------------
# Genome erzeugen
# -------------------------------------------------------------------

func create_genome() -> Array[int]:
	var g: Array[int] = []
	var weighted = [1,2,4,4,4, 3,3,3,3, 5,5,5,5]
	for i in range(room_count):
		g.append(weighted[randi_range(0, weighted.size()-1)])
	return g


# -------------------------------------------------------------------
# Fitness berechnen
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
# DUNGEON GENERIEREN – FIXED VERSION
# -------------------------------------------------------------------

func generate_from_genome(genome: Array[int]) -> Dictionary:

	used_doors.clear()
	open_doors.clear()

	var stats = {
		"room_score": 0,
		"open_doors": 0,
		"placed_rooms": 0
	}

	var overlap_count := 0
	var overlap_limit := 50

	# -------- erster Raum --------
	var type0 = genome[0]
	var room: Node2D = room_scenes[type0 - 1].instantiate()
	add_child(room)
	room.add_to_group("rooms")
	room.global_position = start_position

	# Score nur für erfolgreich platzierten Raum
	stats["room_score"] += (10 if type0 in [3,5] else 1)
	stats["placed_rooms"] += 1
	open_doors.append_array(get_doors(room))

	# -------- weitere Räume --------
	for i in range(1, genome.size()):

		if open_doors.is_empty():
			break

		var prev: Marker2D = open_doors.pop_front()
		if not is_instance_valid(prev):
			continue

		var placed := false
		var max_attempts := 5

		for attempt in range(max_attempts):

			# ACHTUNG: WIR VERÄNDERN DAS GENOM NICHT!
			var try_rtype := genome[i]

			var test_room: Node2D = room_scenes[try_rtype - 1].instantiate()
			add_child(test_room)
			test_room.add_to_group("rooms")

			var test_doors = get_doors(test_room)
			test_doors.shuffle()

			if test_doors.is_empty():
				test_room.queue_free()
				continue

			for d in test_doors:

				var target_rot = prev.global_rotation + PI
				var delta = target_rot - d.global_rotation
				var snap: float = round(rad_to_deg(delta) / 90.0) * 90.0

				test_room.rotation += deg_to_rad(snap)
				await get_tree().process_frame

				var offset = prev.global_position - d.global_position
				test_room.global_position += offset
				await get_tree().process_frame

				if room_overlaps(test_room):
					test_room.rotation = 0
					test_room.global_position = Vector2.ZERO
					continue

				# Erfolgreich platziert!
				placed = true

				stats["placed_rooms"] += 1
				stats["room_score"] += (10 if try_rtype in [3,5] else 1)

				for d2 in test_doors:
					if d2 != d:
						open_doors.append(d2)

				used_doors.append(prev)
				used_doors.append(d)

				break

			if placed:
				break

			# Raum passte nicht → verwerfen
			test_room.queue_free()

			# Raumtyp NEU testen, aber GENOM NICHT ändern!
			try_rtype = randi_range(1, rooms_available)

		if not placed:
			continue

		if overlap_count > overlap_limit:
			break

	stats["open_doors"] = open_doors.size()
	return stats



# -------------------------------------------------------------------
# GENETIC SEARCH
# -------------------------------------------------------------------

func _run_simple_ga() -> void:
	var best_genome: Array[int] = []
	var best_fitness := -INF

	for attempt in range(200):

		var genome = create_genome()
		_clear_rooms()

		var stats = await generate_from_genome(genome)
		var fitness = compute_fitness(stats)

		print("Layout ", attempt, " -> Fitness =", fitness, " | ", stats)

		if fitness > best_fitness:
			best_fitness = fitness
			best_genome = genome.duplicate()

	# bestes Layout rendern
	_clear_rooms()
	await generate_from_genome(best_genome)

	print("\nBESTES GENOM =", best_genome)
	print("BESTE FITNESS =", best_fitness)
