extends Node2D

@export var room_scenes: Array[PackedScene]
@export var start_room: PackedScene
@export var max_rooms := 15

var placed_rooms := []

func _ready():
	generate()

func generate():
	var first_room = start_room.instantiate()
	add_child(first_room)
	first_room.global_position = Vector2.ZERO
	placed_rooms.append(first_room)

	var open_doors = first_room.get_free_doors()

	while open_doors.size() > 0 and placed_rooms.size() < max_rooms:
		var door = open_doors.pop_back()
		if door.used:
			continue

		var new_room_scene = room_scenes.pick_random()
		var new_room = new_room_scene.instantiate()

		var matching_door = find_matching_door(new_room, door.direction)
		if matching_door == null:
			new_room.queue_free()
			continue

		add_child(new_room)

		# SNAP ROOM
		new_room.global_position = door.global_position - matching_door.position

		# OPTIONAL: Overlap-Check
		if check_overlap(new_room):
			new_room.queue_free()
			continue

		door.used = true
		matching_door.used = true

		placed_rooms.append(new_room)
		open_doors += new_room.get_free_doors()

func find_matching_door(room, from_direction):
	var opposite = {
		"north": "south",
		"south": "north",
		"east": "west",
		"west": "east"
	}

	for door in room.get_free_doors():
		if door.direction == opposite[from_direction]:
			return door
	return null

func check_overlap(new_room):
	var new_rect = new_room.get_global_transform_with_canvas().get_origin()
	for room in placed_rooms:
		if room.get_rect().intersects(new_room.get_rect()):
			return true
	return false
