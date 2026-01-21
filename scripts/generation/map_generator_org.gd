extends Node2D
class_name DungeonGenerator

@export var rooms_folder := "res://scenes/rooms/Rooms/"
@export var closed_doors_folder := "res://scenes/rooms/Closed Doors/"
@export var start_room: PackedScene = load("res://scenes/rooms/Rooms/room_11x11.tscn")
@export var max_rooms := 10
@export var build_best_map_after_ga := true

var placed_rooms: Array[Node2D] = []
var room_type_counts := {}

var world_tilemap: TileMapLayer
var world_tilemap_top: TileMapLayer

var room_lib := RoomLibrary.new()
var placer := RoomPlacer.new()
var baker := WorldBaker.new()
var door_closer: DoorCloser = DoorCloser.new()
var ga := GASearch.new()


func get_random_tilemap() -> TileMapLayer:
	# load scenes
	room_lib.load_rooms(rooms_folder)
	door_closer.load_closed_doors(closed_doors_folder, room_lib)

	print("=== MAP GENERATION START ===")

	# genetic search
	var best = await ga.search_best(self, room_lib, placer, start_room, max_rooms)
	print("🏆 BEST:", best.rooms_placed, "seed:", best.seed)

	# build best map
	if build_best_map_after_ga:
		_clear_generated()
		placed_rooms = await placer.generate_best(
			self, room_lib, start_room, max_rooms, best.genome, best.seed, room_type_counts
		)

		# bake rooms + doors
		baker.ensure_world_tilemaps(self, placed_rooms)
		baker.bake_rooms(placed_rooms)
		door_closer.bake_closed_doors(self, placed_rooms, baker)

		for r in placed_rooms:
			r.visible = false

	return baker.world_floor


func _clear_generated():
	for n in get_tree().get_nodes_in_group("room"):
		if n != null and is_instance_valid(n):
			n.queue_free()

	# falls du closed doors als scenes added:
	for n in get_tree().get_nodes_in_group("closed_door"):
		if n != null and is_instance_valid(n):
			n.queue_free()

	placed_rooms.clear()
	room_type_counts.clear()
