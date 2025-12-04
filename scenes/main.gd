extends Node2D

# wie viele Räume ein Dungeon haben soll (Genom = Länge)
@export var room_count: int = 20

# Startposition vom ersten Raum
@export var start_position: Vector2 = Vector2(500, 500)

# wie viele verschiedene RoomX.tscn es gibt
@export var rooms_available: int = 4

# interne Listen für Türen
var used_doors: Array[Marker2D] = []
var open_doors: Array[Marker2D] = []

# Liste aller geladenen Räume
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

# Räume laden
func _load_room_scenes() -> void:
	room_scenes.clear()

	for i in range(1, rooms_available + 1):
		var path: String = "res://scenes/Room%d.tscn" % i
		if ResourceLoader.exists(path):
			var scene := load(path)
			if scene is PackedScene:
				room_scenes.append(scene)
			else:
				push_warning("Datei ist keine gültige Scene: " + path)
		else:
			push_warning("Fehlt: " + path)


# alle Räume löschen
func _clear_rooms() -> void:
	for r in get_tree().get_nodes_in_group("rooms"):
		r.queue_free()


# Türen eines Raums finden
func get_doors(room: Node2D) -> Array[Marker2D]:
	var arr: Array[Marker2D] = []
	for c in room.get_children():
		if c is Marker2D and c.name.begins_with("Door"):
			arr.append(c)
	return arr


# Area2D des Raums finden (für Overlap-Check)
func get_room_area(room: Node) -> Area2D:
	# versucht direkt "Area2D" zu finden, ansonsten rekursiv
	var area: Area2D = room.get_node_or_null("Area2D")
	if area:
		return area

	# Fallback: irgendein Area2D-Child
	var found := room.find_child("Area2D", true, false)
	if found is Area2D:
		return found

	return null


# prüft, ob sich der Raum mit etwas anderem überschneidet
func room_overlaps(room: Node2D) -> bool:
	var area := get_room_area(room)
	if area == null:
		# Wenn kein Collider, gehen wir von "kein Overlap" aus
		return false

	# Sicherstellen, dass Area auch wirklich scannt
	area.monitoring = true
	area.monitorable = true

	# Achtung: has_overlapping_* funktioniert erst nach mindestens 1 Frame
	return area.has_overlapping_areas() or area.has_overlapping_bodies()


# Genome erzeugen (Raumtypen)
func create_genome() -> Array[int]:
	var g: Array[int] = []
	for i in range(room_count):
		g.append(randi_range(1, rooms_available))
	return g


# Fitness berechnen
func compute_fitness(stats: Dictionary) -> float:
	var f: float = 0.0
	# große Räume gut
	f += float(stats.get("room_score", 0))
	# offene Türen schlecht
	f -= float(stats.get("open_doors", 0)) * 5.0
	# optional: belohne mehr platzierte Räume
	f += float(stats.get("placed_rooms", 0)) * 2.0
	return f


# -------------------------------------------------------------------
# Dungeon bauen aus einem Genom
# -------------------------------------------------------------------

func generate_from_genome(genome: Array[int]) -> Dictionary:
	used_doors.clear()
	open_doors.clear()

	var stats: Dictionary = {
		"room_score": 0,
		"open_doors": 0,
		"placed_rooms": 0
	}

	if genome.is_empty():
		return stats

	# === erster Raum ===
	var type0: int = genome[0]
	var room: Node2D = room_scenes[type0 - 1].instantiate()
	add_child(room)
	room.add_to_group("rooms")

	room.global_position = start_position

	# große Räume belohnen (z.B. Typ 1)
	stats["room_score"] += 10 if type0 == 1 else 1
	stats["placed_rooms"] += 1

	# offene Türen starten
	var doors: Array[Marker2D] = get_doors(room)
	doors.shuffle()
	for d in doors:
		open_doors.append(d)

	# === nächste Räume ===
	for i in range(1, genome.size()):
		# keine offenen Türen mehr -> Ende
		if open_doors.is_empty():
			break

		# nächste freie Tür als Anschluss nehmen
		var prev: Marker2D = open_doors.pop_front()
		if not is_instance_valid(prev):
			continue
		used_doors.append(prev)

		# neuen Raum basierend auf Genomtyp instanzieren
		var rtype: int = genome[i]
		var new_room: Node2D = room_scenes[rtype - 1].instantiate()
		add_child(new_room)
		new_room.add_to_group("rooms")

		stats["room_score"] += 10 if rtype == 1 else 1

		var new_doors: Array[Marker2D] = get_doors(new_room)
		new_doors.shuffle()

		if new_doors.is_empty():
			new_room.queue_free()
			continue

		var new_door: Marker2D = new_doors[0]

		# ----------------------
		# 1) Rotation anpassen
		# ----------------------
		# Zielrotation = gegenüberliegend zur alten Tür
		var target_rot: float = prev.global_rotation + PI
		var delta_rot: float = target_rot - new_door.global_rotation

		# auf 90°-Schritte runden (optional)
		var snap_deg: float = round(rad_to_deg(delta_rot) / 90.0) * 90.0
		new_room.rotation += deg_to_rad(snap_deg)

		# einen Frame warten, damit sich die Türrotation aktualisiert
		await get_tree().process_frame

		# ----------------------
		# 2) Position anpassen
		# ----------------------
		var after_pos: Vector2 = new_door.global_position
		var offset: Vector2 = prev.global_position - after_pos
		new_room.global_position += offset

		# noch 1–2 Frames warten, damit Physik/Kollisionsdaten aktuell sind
		await get_tree().process_frame
		await get_tree().process_frame

		# ----------------------
		# 3) Overlap prüfen
		# ----------------------
		if room_overlaps(new_room):
			# Raum verwirft sich, Türen aus diesem Raum NICHT übernehmen
			new_room.queue_free()
			continue

		# Raum ist gültig platziert
		stats["placed_rooms"] += 1

		# offene Türen aus dem neuen Raum sammeln
		for d2 in new_doors:
			if d2 == new_door:
				continue
			if d2 in used_doors:
				continue
			open_doors.append(d2)

		# die benutzte Tür dieses Raums markieren
		used_doors.append(new_door)

	# offene Türen zählen
	stats["open_doors"] = open_doors.size()
	return stats


# -------------------------------------------------------------------
# Einfacher genetischer Algorithmus
# -------------------------------------------------------------------

# einfacher GA → prüft 100 Layouts, bestes bleibt
func _run_simple_ga() -> void:
	var best_genome: Array[int] = []
	var best_fitness: float = -INF

	for attempt in range(100):

		var genome: Array[int] = create_genome()

		# alte Räume löschen
		_clear_rooms()

		# Layout erzeugen (async wegen await im Generator)
		var stats: Dictionary = await generate_from_genome(genome)
		var fitness: float = compute_fitness(stats)

		print("Layout ", attempt, " -> Fitness = ", fitness, " | Stats: ", stats)

		if fitness > best_fitness:
			best_fitness = fitness
			best_genome = genome.duplicate()

	# bestes Layout anzeigen
	_clear_rooms()
	await generate_from_genome(best_genome)

	print("\nBESTES GENOM = ", best_genome)
	print("BESTE FITNESS = ", best_fitness)
