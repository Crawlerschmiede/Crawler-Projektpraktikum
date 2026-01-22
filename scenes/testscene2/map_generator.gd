# gdlint: disable=max-public-methods

extends Node2D

@export var closed_doors_folder: String = "res://scenes/rooms/Closed Doors/"
var closed_door_scenes: Array[PackedScene] = []
var _closed_door_cache: Dictionary = {}

@export var rooms_folder: String = "res://scenes/rooms/Rooms/"
var room_scenes: Array[PackedScene] = []
@export var start_room: PackedScene
@export var boss_room: PackedScene
@export var max_rooms: int = 10

@export var player_scene: PackedScene
var _corridor_cache: Dictionary = {} # key: String(scene.resource_path) -> bool

# --- Basis-Regeln (werden vom GA überschrieben / mutiert) ---
@export var base_max_corridors: int = 10
@export var base_max_corridor_chain: int = 3
@export_range(0.0, 1.0, 0.01) var base_door_fill_chance: float = 1.0

# --- Genetischer Ansatz ---
@export var ga_total_evals: int = 10  # genau 500 Auswertungen
@export var ga_population_size: int = 40  # 20 * 25 = 500
@export var ga_generations: int = 25
@export var ga_elite_keep: int = 4  # Top 4 bleiben
@export var ga_mutation_rate: float = 0.25
@export var ga_crossover_rate: float = 0.70
@export var ga_seed: int = randi()

# Optional: Wenn du willst, dass nach dem GA die beste Map sofort gebaut wird
@export var build_best_map_after_ga: bool = true

var player: MoveableEntity
var world_tilemap: TileMapLayer
var world_tilemap_top: TileMapLayer
var minimap: TileMapLayer
var room_type_counts: Dictionary = {}

# Laufzeit
var placed_rooms: Array[Node2D] = []
var corridor_count: int = 0

var boss_room_spawned := false


func _get_closed_door_direction(scene: PackedScene) -> String:
	if scene == null:
		return ""

	var key := scene.resource_path
	if _closed_door_cache.has(key):
		return str(_closed_door_cache[key])

	var inst := scene.instantiate()
	var dir := ""

	if inst != null:
		# 1) Falls die Szene selbst direction export hat -> nutzen
		if "direction" in inst:
			dir = str(inst.get("direction")).to_lower()

		# 2) Sonst: Richtung aus Doors/ Door child lesen
		elif inst.has_node("Doors"):
			var doors_node := inst.get_node("Doors")
			for d in doors_node.get_children():
				# dein Door script hat direction property
				if d != null and "direction" in d:
					dir = str(d.get("direction")).to_lower()
					break

		inst.queue_free()

	_closed_door_cache[key] = dir
	return dir

	
func get_closed_door_for_direction(dir: String) -> PackedScene:
	dir = dir.to_lower()

	var candidates: Array[PackedScene] = []
	for s in closed_door_scenes:
		if _get_closed_door_direction(s) == dir:
			candidates.append(s)

	if candidates.is_empty():
		return null
	return candidates.pick_random()

	
func load_closed_door_scenes_from_folder(path: String) -> Array[PackedScene]:
	return load_room_scenes_from_folder(path)

func close_free_doors(parent_node: Node) -> void:
	if closed_door_scenes.is_empty():
		push_warning("⚠ closed_door_scenes leer - lade closed doors zuerst!")
		return

	var total := 0

	for room in placed_rooms:
		if room == null:
			continue
		if not room.has_method("get_free_doors"):
			continue

		var free_doors = room.get_free_doors()
		for door in free_doors:
			if door == null or door.used:
				continue

			var door_scene := get_closed_door_for_direction(door.direction)
			if door_scene == null:
				push_warning("⚠ Keine ClosedDoor Scene für Richtung: " + str(door.direction))
				continue

			var closed_door := door_scene.instantiate() as Node2D
			parent_node.add_child(closed_door)

			# ✅ Snap direkt auf die Tür
			closed_door.global_position = door.global_position
			closed_door.global_rotation = door.global_rotation  # falls Türen rotiert sind

			# ✅ Tür markieren als benutzt
			door.used = true

			total += 1

	print("✔ Closed Doors gesetzt:", total)
	
func debug_print_free_doors() -> void:
	var total := 0
	for r in placed_rooms:
		if r == null or not r.has_method("get_free_doors"):
			continue
		var free = r.get_free_doors()
		if free.size() > 0:
			print("ROOM:", r.name, "free doors:", free.size())
			for d in free:
				print("  -", d.name, "dir:", d.direction, "used:", d.used)
				total += 1
	print("TOTAL FREE DOORS:", total)

# -----------------------------
# GA: Genome / Ergebnis
# -----------------------------
func load_room_scenes_from_folder(path: String) -> Array[PackedScene]:
	var result: Array[PackedScene] = []

	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Folder not found: " + path)
		return result

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
	return result

func _scene_is_corridor(scene: PackedScene) -> bool:
	if scene == null:
		return false

	var key := scene.resource_path
	if _corridor_cache.has(key):
		return bool(_corridor_cache[key])

	# EINMAL instantiaten zum checken (und sofort free)
	var inst := scene.instantiate()
	var is_corr := false
	if inst != null:
		is_corr = ("is_corridor" in inst) and bool(inst.get("is_corridor"))
		inst.queue_free()

	_corridor_cache[key] = is_corr
	return is_corr

class Genome:
	var door_fill_chance: float
	var max_corridors: int
	var max_corridor_chain: int
	var corridor_bias: float  # >1 bevorzugt Corridors, <1 bevorzugt Rooms

	func clone() -> Genome:
		var g := Genome.new()
		g.door_fill_chance = door_fill_chance
		g.max_corridors = max_corridors
		g.max_corridor_chain = max_corridor_chain
		g.corridor_bias = corridor_bias
		return g

	func describe() -> String:
		return (
			"door_fill="
			+ str(door_fill_chance)
			+ ", max_corridors="
			+ str(max_corridors)
			+ ", max_chain="
			+ str(max_corridor_chain)
			+ ", corridor_bias="
			+ str(corridor_bias)
		)


class EvalResult:
	var genome: Genome
	var rooms_placed: int = 0
	var corridors_placed: int = 0
	var seed: int = 0


func get_random_tilemap() -> Dictionary:
	start_room = load("res://scenes/rooms/Rooms/room_11x11.tscn")
	room_scenes = load_room_scenes_from_folder(rooms_folder)
	closed_door_scenes = load_room_scenes_from_folder(closed_doors_folder)
	for s in closed_door_scenes:
		print(" -", s.resource_path, "dir:", _get_closed_door_direction(s))
	print("=== MAP GENERATION START ===")

	# 1) genetische Suche
	var best := await genetic_search_best()
	print(
		"\n🏆 BEST GENOME:",
		best.genome,
		"| rooms:",
		best.rooms_placed,
		"| corridors:",
		best.corridors_placed,
		"| seed:",
		best.seed
	)
	
	minimap = TileMapLayer.new()
	minimap.name = "Minimap"
	minimap.visibility_layer = 1 << 1

	
	# 2) beste Map wirklich bauen
	if build_best_map_after_ga:
		clear_world_tilemaps()
		clear_children_rooms_only()
		await generate_with_genome(best.genome, best.seed, true)
		debug_print_free_doors()
		bake_rooms_into_world_tilemap()

		# Räume optional ausblenden (empfohlen)
		for r in placed_rooms:
			r.visible = false

	return {"floor": world_tilemap, "top": world_tilemap_top, "minimap": minimap}


func get_required_scenes() -> Array[PackedScene]:
	var required: Array[PackedScene] = []

	for s in room_scenes:
		if s == null:
			continue
		var inst := s.instantiate()
		if inst == null:
			continue

		# nur wenn Variable existiert
		if "required_min_count" in inst:
			var req := int(inst.get("required_min_count"))
			if req > 0:
				required.append(s)

		inst.queue_free()

	# Boss optional auch prüfen
	if boss_room != null:
		var b := boss_room.instantiate()
		if b != null and "required_min_count" in b and int(b.get("required_min_count")) > 0:
			required.append(boss_room)
		if b != null:
			b.queue_free()

	return required


func ensure_required_rooms(
	parent_node: Node, local_placed: Array[Node2D], genome: Genome, verbose: bool
) -> void:
	var required_scenes := get_required_scenes()
	if required_scenes.is_empty():
		return

	# freie Türen nochmal sammeln
	var free_doors: Array = []
	for r in local_placed:
		if r != null and r.has_method("get_free_doors"):
			for d in r.get_free_doors():
				if d != null and not d.used:
					free_doors.append(d)

	free_doors.shuffle()

	for scene in required_scenes:
		var key := get_room_key(scene)

		# Wie oft muss der rein?
		var temp := scene.instantiate()
		if temp == null:
			continue
		var required_min := int(get_rule(temp, "required_min_count", 0))
		temp.queue_free()

		var current := int(room_type_counts.get(key, 0))

		while current < required_min and free_doors.size() > 0:
			var door = free_doors.pop_front()
			if door == null or door.used:
				continue

			# Versuch: genau diesen Raum platzieren
			var res := try_place_specific_room(scene, door, parent_node, local_placed, genome)
			if res:
				current += 1
				room_type_counts[key] = current
				if verbose:
					print("✔ REQUIRED room placed:", key, "(", current, "/", required_min, ")")
			else:
				# wenn es nicht passt -> nächste Tür
				pass


func get_room_key(scene: PackedScene) -> String:
	var key = scene.resource_path
	if scene == null:
		return ""
	var inst := scene.instantiate()
	if inst.get_groups():
		key = inst.get_groups()[0]
		print("use key: ", key)
	# resource_path ist stabil -> perfekt als key
	return scene.resource_path


func get_rule(room_instance: Node, var_name: String, default_value):
	if room_instance == null:
		return default_value
	if var_name in room_instance:
		return room_instance.get(var_name)
	return default_value


func can_spawn_room(scene: PackedScene, room_instance: Node, placed_count: int) -> bool:
	# 1) Regeln aus Raum lesen (wenn nicht vorhanden -> default)
	var spawn_chance: float = float(get_rule(room_instance, "spawn_chance", 1.0))
	var max_count: int = int(get_rule(room_instance, "max_count", 999999))
	var min_rooms_before_spawn: int = int(get_rule(room_instance, "min_rooms_before_spawn", 0))

	# 2) zu früh?
	if placed_count < min_rooms_before_spawn:
		return false

	# 3) Max Count erreicht?
	var key := get_room_key(scene)
	var already := int(room_type_counts.get(key, 0))
	if already >= max_count:
		return false

	# 4) Chance
	if spawn_chance < 1.0 and randf() > spawn_chance:
		return false

	return true


# -----------------------------
# GENETIC SEARCH (500 Läufe)
# -----------------------------
func genetic_search_best() -> EvalResult:
	if room_scenes.is_empty() or start_room == null:
		push_error("❌ [GA] room_scenes leer oder start_room NULL")
		var dummy := EvalResult.new()
		dummy.genome = make_default_genome()
		return dummy

	# harte Absicherung, falls jemand Exportwerte falsch setzt
	ga_population_size = max(2, ga_population_size)
	ga_generations = max(1, ga_generations)
	ga_total_evals = max(1, ga_total_evals)

	# Wir erzwingen exakt 500 Auswertungen (oder ga_total_evals)
	# Wenn pop*gen != total, passen wir gen an.
	var target := ga_total_evals
	var pop := ga_population_size
	var gen := ga_generations
	if pop * gen != target:
		gen = int(ceil(float(target) / float(pop)))
		ga_generations = gen
		print("⚠ [GA] pop*gen != total. Setze generations auf:", gen, "(evals=", pop * gen, ")")

	seed(ga_seed)

	# initial population
	var population: Array[Genome] = []
	for i in range(pop):
		population.append(random_genome())

	var best_overall := EvalResult.new()
	best_overall.genome = make_default_genome()
	best_overall.rooms_placed = -1
	best_overall.corridors_placed = 0
	best_overall.seed = ga_seed

	var eval_counter := 0

	for g_i in range(gen):
		# --- evaluate population ---
		var results: Array[EvalResult] = []
		for i in range(pop):
			if eval_counter >= target:
				break

			var trial_seed := ga_seed + eval_counter * 17 + g_i * 101
			var res := await evaluate_genome(population[i], trial_seed)
			results.append(res)
			eval_counter += 1

		# sort desc by rooms placed
		results.sort_custom(
			func(a: EvalResult, b: EvalResult) -> bool: return a.rooms_placed > b.rooms_placed
		)

		# update best
		if results.size() > 0 and results[0].rooms_placed > best_overall.rooms_placed:
			best_overall = results[0]

		print(
			"[GA] Gen",
			g_i,
			"| evals:",
			eval_counter,
			"/",
			target,
			"| best_this_gen:",
			results[0].rooms_placed,
			"| best_overall:",
			best_overall.rooms_placed
		)

		# --- build next generation ---
		# selection pool: top half
		var pool: Array[Genome] = []
		var half: int = max(2, int(results.size() / 2))
		for k in range(half):
			pool.append(results[k].genome)

		# elites
		var next_pop: Array[Genome] = []
		for e in range(min(ga_elite_keep, results.size())):
			next_pop.append(results[e].genome.clone())

		# fill rest
		while next_pop.size() < pop:
			var child: Genome
			if randf() < ga_crossover_rate and pool.size() >= 2:
				var p1 := pool[randi() % pool.size()]
				var p2 := pool[randi() % pool.size()]
				child = crossover(p1, p2)
			else:
				child = pool[randi() % pool.size()].clone()

			if randf() < ga_mutation_rate:
				mutate(child)

			next_pop.append(child)

		population = next_pop

		if eval_counter >= target:
			break

	return best_overall


func evaluate_genome(genome: Genome, trial_seed: int) -> EvalResult:
	# Wir generieren in einem temporären Container (wird danach freigegeben)
	var container := Node2D.new()
	container.name = "_GA_CONTAINER_"
	add_child(container)

	# echte Generierung (ohne Debug-Print spam)
	var stats := await generate_with_genome(genome, trial_seed, false, container)

	container.queue_free()

	var res := EvalResult.new()
	res.genome = genome
	res.rooms_placed = stats.rooms
	res.corridors_placed = stats.corridors
	res.seed = trial_seed
	return res


# -----------------------------
# GENERATION mit Parametern
# -----------------------------
class GenStats:
	var rooms: int = 0
	var corridors: int = 0


func generate_with_genome(
	genome: Genome, trial_seed: int, verbose: bool, parent_override: Node = null
) -> GenStats:
	seed(trial_seed)
	room_type_counts.clear()
	var stats := GenStats.new()

	# lokale state für diesen Lauf
	var local_placed: Array[Node2D] = []
	var local_corridor_count := 0
	var boss_room_spawned := false
	# parent bestimmen (GA-Container oder echter Generator-Node)
	var parent_node: Node = parent_override if parent_override != null else self

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

		if genome.door_fill_chance < 1.0 and randf() > genome.door_fill_chance:
			continue

		# Raum-Root finden
		var from_room: Node = door.get_parent()
		while from_room != null and not from_room.is_in_group("room"):
			from_room = from_room.get_parent()
		if from_room == null:
			if verbose:
				push_error("❌ [DOOR] Konnte Raum-Root nicht finden für Door: " + str(door.name))
			continue

		var from_chain: int = int(from_room.get_meta("corridor_chain", 0))
		var from_corridor: bool = is_corridor_room(from_room)

		# Kandidaten in zufälliger Reihenfolge
		var candidates := room_scenes.duplicate()
		candidates.shuffle()

		# optionaler Bias: Corridors vs Rooms
		# Wir sortieren leicht um (ohne massiv umzubauen):
		# corridor_bias > 1: Corridors eher nach vorne
		# corridor_bias < 1: Corridors eher nach hinten
		if abs(genome.corridor_bias - 1.0) > 0.01:
			candidates.sort_custom(func(a: PackedScene, b: PackedScene) -> bool:
				var ca := _scene_is_corridor(a)
				var cb := _scene_is_corridor(b)

				# bias > 1: corridors nach vorne
				if genome.corridor_bias > 1.0:
					return int(ca) > int(cb)

				# bias < 1: corridors nach hinten
				return int(ca) < int(cb)
			)

		var placed := false
		for room_scene in candidates:
			if room_scene == null:
				continue

			var new_room := room_scene.instantiate() as Node2D
			if not can_spawn_room(room_scene, new_room, local_placed.size()):
				new_room.queue_free()
				continue
			if new_room == null:
				continue

			if not new_room.has_method("get_free_doors"):
				new_room.queue_free()
				continue

			var to_corridor := is_corridor_room(new_room)

			# ---------- Corridor-Regeln ----------
			if to_corridor:
				if local_corridor_count >= genome.max_corridors:
					new_room.queue_free()
					continue

				var new_chain := from_chain + 1
				if new_chain > genome.max_corridor_chain:
					# ab hier: Corridor wäre zu lang -> Corridor-Kandidat skip
					new_room.queue_free()
					continue

			# WICHTIG: wenn die Kette voll ist, erzwingen wir faktisch einen Raum,
			# indem wir Corridor-Kandidaten wegfiltern. Das heißt:
			# - Wenn es *irgendeinen* Raum gibt, der passt -> er wird gesetzt.
			# - Wenn kein Raum passt -> Tür bleibt leer.
			if from_corridor and from_chain >= genome.max_corridor_chain:
				if to_corridor:
					new_room.queue_free()
					continue

			var matching_door = find_matching_door(new_room, door.direction)
			if matching_door == null:
				new_room.queue_free()
				continue

			parent_node.add_child(new_room)
			new_room.add_to_group("room")

			# Global Snap
			var offset: Vector2 = matching_door.global_position - new_room.global_position
			new_room.global_position = door.global_position - offset
			new_room.force_update_transform()

			# Collision AABB
			var overlap := check_overlap_aabb(new_room, local_placed)
			if overlap.overlaps:
				new_room.queue_free()
				continue

			# Erfolg
			door.used = true
			matching_door.used = true

			if to_corridor:
				local_corridor_count += 1
				new_room.set_meta("corridor_chain", from_chain + 1)
			else:
				new_room.set_meta("corridor_chain", 0)

			var room_tm := new_room.get_node("TileMapLayer") as TileMapLayer
			if room_tm:
				var tile_size := room_tm.tile_set.tile_size
				var tile_origin := Vector2i(
					int(round(new_room.global_position.x / tile_size.x)),
					int(round(new_room.global_position.y / tile_size.y))
				)
				new_room.set_meta("tile_origin", tile_origin)

			local_placed.append(new_room)
			next_doors += new_room.get_free_doors()
			# Raumtyp zählen
			var key := get_room_key(room_scene)
			room_type_counts[key] = int(room_type_counts.get(key, 0)) + 1

			placed = true
			break

		if not placed:
			# Tür bleibt offen/leer
			pass

		if current_doors.is_empty():
			current_doors = next_doors
			next_doors = []

	# stats
	stats.rooms = local_placed.size()
	stats.corridors = local_corridor_count

	# Wenn es die echte Map ist, halten wir den finalen state global fest
	if parent_override == null:
		placed_rooms = local_placed
		corridor_count = local_corridor_count
	ensure_required_rooms(parent_node, local_placed, genome, verbose)

	return stats


# gdlint: disable=max-returns
func try_place_specific_room(
	scene: PackedScene, door, parent_node: Node, local_placed: Array[Node2D], _genome: Genome
) -> bool:
	if scene == null:
		return false

	var new_room := scene.instantiate() as Node2D
	if new_room == null:
		return false

	if not new_room.has_method("get_free_doors"):
		new_room.queue_free()
		return false

	# Regeln ignorieren? Nein, required darf trotzdem max_count respektieren:
	if not can_spawn_room(scene, new_room, local_placed.size()):
		new_room.queue_free()
		return false

	var matching_door = find_matching_door(new_room, door.direction)
	if matching_door == null:
		new_room.queue_free()
		return false

	parent_node.add_child(new_room)
	new_room.add_to_group("room")

	# Snap
	var offset: Vector2 = matching_door.global_position - new_room.global_position
	new_room.global_position = door.global_position - offset
	new_room.force_update_transform()

	# Collision
	var overlap := check_overlap_aabb(new_room, local_placed)
	if overlap.overlaps:
		new_room.queue_free()
		return false

	# Erfolg
	door.used = true
	matching_door.used = true

	# corridor chain meta (wie bei dir)
	var from_room: Node = door.get_parent()
	while from_room != null and not from_room.is_in_group("room"):
		from_room = from_room.get_parent()
	var from_chain: int = int(from_room.get_meta("corridor_chain", 0)) if from_room != null else 0

	if is_corridor_room(new_room):
		new_room.set_meta("corridor_chain", from_chain + 1)
	else:
		new_room.set_meta("corridor_chain", 0)

	# tile_origin meta
	var room_tm := new_room.get_node_or_null("TileMapLayer") as TileMapLayer
	if room_tm:
		var tile_size := room_tm.tile_set.tile_size
		var tile_origin := Vector2i(
			int(round(new_room.global_position.x / tile_size.x)),
			int(round(new_room.global_position.y / tile_size.y))
		)
		new_room.set_meta("tile_origin", tile_origin)

	local_placed.append(new_room)

	return true


# gdlint: enable=max-returns


# -----------------------------
# CORRIDOR CHECK
# -----------------------------
func is_corridor_room(room: Node) -> bool:
	if room == null:
		return false

	# Achtung: Door Nodes etc. laufen hier auch rein -> sauber filtern
	if (
		not room.is_in_group("room")
		and room.get_parent() != null
		and room.get_parent().is_in_group("room")
	):
		# oft ist room hier eigentlich ein Door/Child
		pass

	if not ("is_corridor" in room):
		# Wir spammen NICHT im GA (sonst 500x). Daher nur in non-GA erzeugen.
		# -> Wir geben einfach false zurück.
		return false

	var value = room.get("is_corridor")
	return typeof(value) == TYPE_BOOL and value


# -----------------------------
# DOOR MATCH
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
# COLLISION (AABB)
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

			# ✅ Achtung: CollisionShape2D kann verschoben sein!
			var center := cs.global_position
			rects.append(Rect2(center - shape.extents, shape.extents * 2.0))

	return rects
	
func check_overlap_aabb(new_room: Node2D, against: Array[Node2D]) -> OverlapResult:
	var result := OverlapResult.new()

	# ✅ Alle rects vom neuen room holen
	var new_rects := _get_room_rects(new_room)

	# Wenn gar keine Shapes vorhanden -> als Fehler behandeln
	if new_rects.is_empty():
		result.overlaps = true
		result.other_name = "missing_collision"
		return result

	for room in against:
		if room == null or room == new_room:
			continue

		var rects := _get_room_rects(room)
		if rects.is_empty():
			continue

		# ✅ Jede neue Shape gegen jede alte Shape testen
		for a in new_rects:
			for b in rects:
				if a.intersects(b):
					result.overlaps = true
					result.other_name = room.name
					return result

	return result

# -----------------------------
# GA Helpers
# -----------------------------
func make_default_genome() -> Genome:
	var g := Genome.new()
	g.door_fill_chance = base_door_fill_chance
	g.max_corridors = base_max_corridors
	g.max_corridor_chain = base_max_corridor_chain
	g.corridor_bias = 1.0
	return g


func random_genome() -> Genome:
	var g := make_default_genome()
	# breit streuen
	g.door_fill_chance = clamp(randf_range(0.60, 1.0), 0.0, 1.0)
	g.max_corridors = int(clamp(randi_range(0, 25), 0, 9999))
	g.max_corridor_chain = int(clamp(randi_range(1, 4), 0, 10))
	g.corridor_bias = clamp(randf_range(0.6, 1.6), 0.1, 3.0)
	return g


func crossover(a: Genome, b: Genome) -> Genome:
	var c := a.clone()
	# zufällig Gene wählen
	if randf() < 0.5:
		c.door_fill_chance = b.door_fill_chance
	if randf() < 0.5:
		c.max_corridors = b.max_corridors
	if randf() < 0.5:
		c.max_corridor_chain = b.max_corridor_chain
	if randf() < 0.5:
		c.corridor_bias = b.corridor_bias
	return c


func mutate(g: Genome) -> void:
	# kleine Mutationen
	if randf() < 0.5:
		g.door_fill_chance = clamp(g.door_fill_chance + randf_range(-0.12, 0.12), 0.2, 1.0)
	if randf() < 0.5:
		g.max_corridors = int(clamp(g.max_corridors + randi_range(-4, 6), 0, 40))
	if randf() < 0.5:
		g.max_corridor_chain = int(clamp(g.max_corridor_chain + randi_range(-1, 1), 0, 6))
	if randf() < 0.5:
		g.corridor_bias = clamp(g.corridor_bias + randf_range(-0.25, 0.25), 0.3, 2.5)


# -----------------------------
# Utility
# -----------------------------
func bake_rooms_into_world_tilemap() -> void:
	if placed_rooms.is_empty():
		push_error("❌ [BAKE] Keine Räume zum Baken vorhanden")
		return

	# --- WORLD FLOOR ---
	if world_tilemap == null:
		world_tilemap = TileMapLayer.new()
		world_tilemap.name = "WorldFloor"

		# TileSet vom ersten Raum übernehmen (Floor Layer)
		var first_floor := placed_rooms[0].get_node_or_null("TileMapLayer") as TileMapLayer
		if first_floor == null:
			push_error("❌ [BAKE] StartRoom hat keine TileMapLayer (Floor)")
			return

		world_tilemap.tile_set = first_floor.tile_set
		#add_child(world_tilemap)

	# --- WORLD TOP ---
	if world_tilemap_top == null:
		world_tilemap_top = TileMapLayer.new()
		world_tilemap_top.name = "WorldTop"

		# Tileset: vom ersten vorhandenen TopLayer holen, sonst Floor Tileset nutzen
		var first_top := placed_rooms[0].get_node_or_null("TopLayer") as TileMapLayer
		if first_top != null:
			world_tilemap_top.tile_set = first_top.tile_set
		else:
			world_tilemap_top.tile_set = world_tilemap.tile_set

		#add_child(world_tilemap_top)

	world_tilemap.clear()
	world_tilemap_top.clear()

	# --- Räume backen ---
	for room in placed_rooms:
		var floor_tm := room.get_node_or_null("TileMapLayer") as TileMapLayer
		var top_tm := room.get_node_or_null("TopLayer") as TileMapLayer  # <- Name anpassen falls anders!

		var room_offset: Vector2i = room.get_meta("tile_origin", Vector2i.ZERO)

		# FLOOR kopieren
		if floor_tm != null:
			add_room_layer_to_minimap(room)
			copy_layer_into_world(floor_tm, world_tilemap, room_offset)
			bake_closed_doors_into_world()

		# TOP kopieren
		if top_tm != null:
			copy_layer_into_world(top_tm, world_tilemap_top, room_offset)

	print(
		"✔ [BAKE] WorldTileMaps erstellt | Floor tiles:",
		world_tilemap.get_used_cells().size(),
		"| Top tiles:",
		world_tilemap_top.get_used_cells().size()
	)

func bake_closed_doors_into_world() -> void:
	if world_tilemap == null or world_tilemap_top == null:
		push_error("❌ world_tilemap/world_tilemap_top ist null - bake_rooms_into_world_tilemap zuerst!")
		return

	var total := 0

	for room in placed_rooms:
		if room == null or not room.has_method("get_free_doors"):
			continue

		var room_offset: Vector2i = room.get_meta("tile_origin", Vector2i.ZERO)

		for door in room.get_free_doors():
			if door == null or door.used:
				continue

			var door_scene := get_closed_door_for_direction(str(door.direction))
			if door_scene == null:
				push_warning("⚠ Keine ClosedDoor Scene für Richtung: " + str(door.direction))
				continue

			var inst := door_scene.instantiate() as Node2D
			if inst == null:
				continue
			add_child(inst)

			# ✅ matching door IN closed-door scene finden
			var matching := _find_any_door_node(inst)
			if matching == null:
				push_warning("⚠ ClosedDoor hat keine Door Nodes: " + door_scene.resource_path)
				inst.queue_free()
				continue

			# ✅ SNAPPEN wie bei Räumen:
			# closed door so bewegen, dass matching door genau auf echte Tür liegt
			var offset: Vector2 = matching.global_position - inst.global_position
			inst.global_position = door.global_position - offset
			inst.force_update_transform()

			# tile_origin bestimmen (wie bei rooms)
			var tile_size := world_tilemap.tile_set.tile_size
			var tile_origin := Vector2i(
				int(round(inst.global_position.x / tile_size.x)),
				int(round(inst.global_position.y / tile_size.y))
			)

			# TileMaps holen
			var src_floor := inst.get_node_or_null("TileMapLayer") as TileMapLayer
			var src_top := inst.get_node_or_null("TopLayer") as TileMapLayer

			if src_floor != null:
				copy_layer_into_world(src_floor, world_tilemap, tile_origin)
			if src_top != null:
				copy_layer_into_world(src_top, world_tilemap_top, tile_origin)

			inst.queue_free()

			door.used = true
			total += 1

	print("✔ [BAKE] Closed Doors gebacken:", total)


func _find_any_door_node(root: Node) -> Node:
	if root == null:
		return null

	if root.has_node("Doors"):
		var doors := root.get_node("Doors")
		for d in doors.get_children():
			if d != null and ("direction" in d):
				return d
	return null

var room_id = 0
func copy_layer_into_world(src: TileMapLayer, dst: TileMapLayer, offset: Vector2i) -> void:
	for cell in src.get_used_cells():
		var source_id := src.get_cell_source_id(cell)
		var atlas := src.get_cell_atlas_coords(cell)
		var alt := src.get_cell_alternative_tile(cell)
		dst.set_cell(cell + offset, source_id, atlas, alt)           

func add_room_layer_to_minimap(room: Node2D) -> void:
	if minimap == null:
		return

	var floor_tm := room.get_node_or_null("TileMapLayer") as TileMapLayer
	if floor_tm == null:
		return

	# Tileset 1x setzen
	if minimap.tile_set == null:
		minimap.tile_set = floor_tm.tile_set

	# origin ist WORLD cell origin
	var origin: Vector2i = room.get_meta("tile_origin", Vector2i.ZERO)
	var layer_name := "Room_%s_%s" % [origin.x, origin.y]

	if minimap.has_node(layer_name):
		return

	# --- Raumlayer erstellen ---
	var room_layer := TileMapLayer.new()
	room_layer.name = layer_name
	room_layer.tile_set = floor_tm.tile_set
	room_layer.visible = false
	room_layer.visibility_layer = 1 << 1

	room_layer.set_meta("tile_origin", origin)

	var tile_size: Vector2i = floor_tm.tile_set.tile_size
	room_layer.position = Vector2(origin.x * tile_size.x, origin.y * tile_size.y)

	minimap.add_child(room_layer)

	# ✅ Tiles 1:1 kopieren (ohne Offset!)
	for cell in floor_tm.get_used_cells():
		var source_id := floor_tm.get_cell_source_id(cell)
		var atlas := floor_tm.get_cell_atlas_coords(cell)
		var alt := floor_tm.get_cell_alternative_tile(cell)
		room_layer.set_cell(cell, source_id, atlas, alt)



func clear_children_rooms_only() -> void:
	# löscht alles außer dem Generator-Node selbst
	for c in get_children():
		if c == null:
			continue
		# GA Container kann auch weg
		c.queue_free()
	placed_rooms.clear()
	corridor_count = 0

func clear_world_tilemaps() -> void:
	if world_tilemap != null and is_instance_valid(world_tilemap):
		world_tilemap.queue_free()
	world_tilemap = null

	if world_tilemap_top != null and is_instance_valid(world_tilemap_top):
		world_tilemap_top.queue_free()
	world_tilemap_top = null


func get_main_tilemap() -> TileMapLayer:
	for room in placed_rooms:
		if room.has_node("TileMapLayer"):
			return room.get_node("TileMapLayer")
	return null
