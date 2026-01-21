extends Node2D

@export var spawn_chance: float = 1.0
@export var max_count: int = 999
@export var min_rooms_before_spawn: int = 0
@export var is_corridor := true
@export var required_min_count: int = 0

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
