extends Node2D

@onready var tilemap: TileMap = $TileMapLayer
@onready var doors := $Doors.get_children()

func get_free_doors():
	var result = []
	for door in doors:
		if not door.used:
			result.append(door)
	return result
