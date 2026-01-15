extends Node2D

@export var is_corridor := true

@onready var tilemap = $TileMapLayer
@onready var doors = $Doors.get_children()


func get_free_doors():
	if not has_node("Doors"):
		push_error("❌ Room has NO 'Doors' node: " + name)
		return []

	var result = []

	for door in $Doors.get_children():
		if door is not Door:
			push_error("❌ Child is not Door: " + door.name)
			continue

		if not door.used:
			result.append(door)

	return result
