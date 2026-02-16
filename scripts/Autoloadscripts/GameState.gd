extends Node

var world_index: int = 0
var map_blueprint: Dictionary = {}

func reset_new_game() -> void:
	world_index = 0
	map_blueprint = {}

func to_dict() -> Dictionary:
	return {
		"world_index": world_index,
		"map_blueprint": map_blueprint,
	}

func from_dict(d: Dictionary) -> void:
	world_index = int(d.get("world_index", 0))
	var bp = d.get("map_blueprint", {})
	map_blueprint = bp if typeof(bp) == TYPE_DICTIONARY else {}
