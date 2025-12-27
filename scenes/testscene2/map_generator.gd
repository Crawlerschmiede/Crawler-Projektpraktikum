extends Node2D

@export var room_scenes: Array[PackedScene]
@export var start_room: PackedScene
@export var max_rooms: int = 200

# --- Corridor-Regeln ---
@export var max_corridors: int = 10
@export var max_corridor_chain: int = 3
@export_range(0.0, 1.0, 0.01) var door_fill_chance: float = 1.0

var placed_rooms: Array[Node2D] = []
var corridor_count: int = 0


func _ready() -> void:
	print("=== MAP GENERATION START ===")
	await generate()
	print("=== MAP GENERATION END ===")


func generate() -> void:
	# ---------- START ROOM ----------
	if start_room == null:
		push_error("❌ [GENERATOR] start_room ist NULL")
		return

	var first_room := start_room.instantiate() as Node2D
	if first_room == null:
		push_error("❌ [GENERATOR] start_room.instantiate() ist kein Node2D")
		return

	add_child(first_room)
	first_room.global_position = Vector2.ZERO
	first_room.add_to_group("room")
	first_room.set_meta("corridor_chain", 0)

	placed_rooms.append(first_room)

	if not first_room.has_method("get_free_doors"):
		push_error("❌ [ROOM] Start room hat kein get_free_doors()")
		return

	if is_corridor_room(first_room):
		corridor_count += 1

	print("✔ Start room:", first_room.name)

	var current_doors: Array = first_room.get_free_doors()
	var next_doors: Array = []

	# ---------- MAIN LOOP ----------
	while current_doors.size() > 0 and placed_rooms.size() < max_rooms:
		var door = current_doors.pop_front()
		if door == null or door.used:
			continue

		if door_fill_chance < 1.0 and randf() > door_fill_chance:
			continue

		var from_room : Node = door.get_parent()
		while from_room != null and not from_room.is_in_group("room"):
			from_room = from_room.get_parent()

		if from_room == null:
			push_error("❌ [DOOR] Konnte Raum-Root nicht finden für Door: " + door.name)
			continue

		var from_corridor := is_corridor_room(from_room)
		var from_chain: int = from_room.get_meta("corridor_chain", 0)

		var candidates := room_scenes.duplicate()
		candidates.shuffle()

		var placed := false
		var last_fail_reason := ""

		for room_scene in candidates:
			var new_room := room_scene.instantiate() as Node2D
			if new_room == null:
				continue

			if not new_room.has_method("get_free_doors"):
				last_fail_reason = "kein get_free_doors()"
				new_room.queue_free()
				continue

			var to_corridor := is_corridor_room(new_room)

			# ---------- CORRIDOR REGELN ----------
			if to_corridor:
				if corridor_count >= max_corridors:
					last_fail_reason = "MaxCorridors erreicht"
					new_room.queue_free()
					continue

				var new_chain := from_chain + 1
				if new_chain > max_corridor_chain:
					last_fail_reason = "Corridor-Kette > " + str(max_corridor_chain)
					new_room.queue_free()
					continue

			var matching_door = find_matching_door(new_room, door.direction)
			if matching_door == null:
				last_fail_reason = "kein passender Door"
				new_room.queue_free()
				continue

			add_child(new_room)
			new_room.add_to_group("room")

			# ---------- GLOBAL SNAP ----------
			var offset: Vector2 = matching_door.global_position - new_room.global_position
			new_room.global_position = door.global_position - offset

			await get_tree().physics_frame
			await get_tree().physics_frame

			# ---------- COLLISION ----------
			var overlap := await check_overlap_verbose(new_room)
			if overlap.overlaps:
				last_fail_reason = "Collision mit " + overlap.other_name
				new_room.queue_free()
				continue

			# ---------- ERFOLG ----------
			door.used = true
			matching_door.used = true

			if to_corridor:
				corridor_count += 1
				new_room.set_meta("corridor_chain", from_chain + 1)
			else:
				new_room.set_meta("corridor_chain", 0)

			placed_rooms.append(new_room)
			next_doors += new_room.get_free_doors()

			print("✔ Room placed:", new_room.name, "| corridor:", to_corridor, "| chain:", new_room.get_meta("corridor_chain"))
			placed = true
			break

		if not placed:
			print("✖ Door", door.name, "failed:", last_fail_reason)

		if current_doors.is_empty():
			current_doors = next_doors
			next_doors = []


# ---------- CORRIDOR CHECK ----------
func is_corridor_room(room: Node) -> bool:
	if room == null:
		return false

	if not ("is_corridor" in room):
		push_error(
			"❌ Room '" + room.name +
			"' hat KEINE Variable 'is_corridor'.\n" +
			"➡ Ergänze im Room-Script:\n@export var is_corridor: bool"
		)
		return false

	var value = room.get("is_corridor")
	if typeof(value) != TYPE_BOOL:
		push_error("❌ 'is_corridor' in '" + room.name + "' ist kein bool")
		return false

	return value


# ---------- DOOR MATCH ----------
func find_matching_door(room: Node, from_direction: String):
	var opposite := {
		"north": "south",
		"south": "north",
		"east": "west",
		"west": "east"
	}

	if not opposite.has(from_direction):
		return null

	for d in room.get_free_doors():
		if d.direction == opposite[from_direction]:
			return d

	return null


# ---------- COLLISION ----------
class OverlapResult:
	var overlaps: bool = false
	var other_name: String = ""


func check_overlap_verbose(new_room: Node2D) -> OverlapResult:
	var result := OverlapResult.new()

	var new_cs := new_room.get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
	if new_cs == null:
		result.overlaps = true
		result.other_name = "missing_collision"
		return result

	var new_shape := new_cs.shape as RectangleShape2D
	if new_shape == null:
		result.overlaps = true
		result.other_name = "wrong_shape"
		return result

	var new_rect := Rect2(
		new_room.global_position - new_shape.extents,
		new_shape.extents * 2.0
	)

	for room in placed_rooms:
		if room == null or room == new_room:
			continue

		var cs := room.get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
		if cs == null:
			continue

		var shape := cs.shape as RectangleShape2D
		if shape == null:
			continue

		var rect := Rect2(
			room.global_position - shape.extents,
			shape.extents * 2.0
		)

		if new_rect.intersects(rect):
			result.overlaps = true
			result.other_name = room.name
			return result

	return result
