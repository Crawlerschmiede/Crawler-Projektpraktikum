extends Node2D

@export var room_scenes: Array[PackedScene]
@export var start_room: PackedScene
@export var max_rooms := 200

var placed_rooms: Array = []

func _ready():
	print("=== MAP GENERATION START ===")
	await generate()
	print("=== MAP GENERATION END ===")


	# ---------- MAIN LOOP (BFS / WAVES) ----------
func generate():
	# ---------- START ROOM ----------
	if start_room == null:
		push_error("❌ start_room ist NULL!")
		return

	var first_room = start_room.instantiate()
	add_child(first_room)
	first_room.global_position = Vector2.ZERO
	first_room.add_to_group("room")
	placed_rooms.append(first_room)

	if not first_room.has_method("get_free_doors"):
		push_error("❌ Start room hat kein get_free_doors()")
		return

	print("✔ Start room instantiated:", first_room.name)

	var current_doors: Array = first_room.get_free_doors()
	var next_doors: Array = []

	print("→ Start room doors:", current_doors.size())


	# ---------- MAIN LOOP (BFS / WAVES) ----------
	while current_doors.size() > 0 and placed_rooms.size() < max_rooms:
		print("\n=== DOOR WAVE ===")
		print("Rooms:", placed_rooms.size(), "Current doors:", current_doors.size())

		var door = current_doors.pop_front()

		if door.used:
			continue

		print("→ Using door:", door.name, "Direction:", door.direction)

		var candidates = room_scenes.duplicate()
		candidates.shuffle()

		var placed := false

		for room_scene in candidates:
			var new_room = room_scene.instantiate()

			if not new_room.has_method("get_free_doors"):
				new_room.queue_free()
				continue

			var matching_door = find_matching_door(new_room, door.direction)
			if matching_door == null:
				new_room.queue_free()
				continue

			add_child(new_room)
			new_room.add_to_group("room")

			# ---------- 🔥 KORREKTER GLOBAL SNAP ----------
			var offset = matching_door.global_position - new_room.global_position
			new_room.global_position = door.global_position - offset

			# OPTIONAL: Grid-Snap (empfohlen)
			# new_room.global_position = new_room.global_position.snapped(Vector2(320, 320))

			# ---------- PHYSICS UPDATE ----------
			await get_tree().physics_frame
			await get_tree().physics_frame

			# ---------- OVERLAP CHECK ----------
			if await check_overlap(new_room):
				print("✖ Overlap → room removed:", new_room.name)
				new_room.queue_free()
				continue

			# ---------- ✅ ERFOLG ----------
			door.used = true
			matching_door.used = true

			placed_rooms.append(new_room)
			next_doors += new_room.get_free_doors()

			print("✔ Room placed:", new_room.name)
			placed = true
			break

		if not placed:
			print("✖ No room fits for door:", door.name)

		# ---------- NEXT WAVE ----------
		if current_doors.is_empty():
			print("➡ Switching to next door wave:", next_doors.size())
			current_doors = next_doors
			next_doors = []


# ---------- DOOR MATCHING ----------
func find_matching_door(room, from_direction):
	var opposite = {
		"north": "south",
		"south": "north",
		"east": "west",
		"west": "east"
	}

	print("Searching matching door for direction:", from_direction)

	for door in room.get_free_doors():
		print("  checking:", door.name, "dir:", door.direction)
		if door.direction == opposite[from_direction]:
			print("  ✔ MATCH:", door.name)
			return door

	print("  ✖ NO MATCH FOUND")
	return null


# ---------- OVERLAP CHECK ----------
func check_overlap(new_room: Node2D) -> bool:
	var new_cs: CollisionShape2D = new_room.get_node_or_null("Area2D/CollisionShape2D")
	if new_cs == null:
		push_error("❌ Room has no Area2D/CollisionShape2D: " + new_room.name)
		return true

	var new_rect_shape := new_cs.shape as RectangleShape2D
	if new_rect_shape == null:
		push_error("❌ CollisionShape2D is not RectangleShape2D in: " + new_room.name)
		return true

	# Bounding Rect vom neuen Raum (global)
	var new_rect := Rect2(
		new_room.global_position - new_rect_shape.extents,
		new_rect_shape.extents * 2.0
	)

	# gegen alle bestehenden Räume prüfen
	for room in placed_rooms:
		if room == null or room == new_room:
			continue
		if not (room is Node2D):
			continue

		var room2d := room as Node2D

		var cs: CollisionShape2D = room2d.get_node_or_null("Area2D/CollisionShape2D")
		if cs == null:
			continue

		var rect_shape := cs.shape as RectangleShape2D
		if rect_shape == null:
			continue

		var room_rect := Rect2(
			room2d.global_position - rect_shape.extents,
			rect_shape.extents * 2.0
		)

		if new_rect.intersects(room_rect):
			return true

	return false
