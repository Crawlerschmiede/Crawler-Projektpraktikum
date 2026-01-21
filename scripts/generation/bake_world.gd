extends RefCounted
class_name WorldBaker

var world_floor: TileMapLayer
var world_top: TileMapLayer

func ensure_world_tilemaps(parent: Node, placed_rooms: Array[Node2D]) -> void:
	if placed_rooms.is_empty():
		return

	if world_floor == null:
		world_floor = TileMapLayer.new()
		world_floor.name = "WorldFloor"
		var first_floor := placed_rooms[0].get_node("TileMapLayer") as TileMapLayer
		world_floor.tile_set = first_floor.tile_set
		parent.add_child(world_floor)

	if world_top == null:
		world_top = TileMapLayer.new()
		world_top.name = "WorldTop"
		world_top.tile_set = world_floor.tile_set
		parent.add_child(world_top)

	world_floor.clear()
	world_top.clear()


func bake_rooms(placed_rooms: Array[Node2D]) -> void:
	for room in placed_rooms:
		var floor_tm := room.get_node_or_null("TileMapLayer") as TileMapLayer
		var top_tm := room.get_node_or_null("TopLayer") as TileMapLayer
		var offset = room.get_meta("tile_origin", Vector2i.ZERO)

		if floor_tm: _copy_layer(floor_tm, world_floor, offset)
		if top_tm: _copy_layer(top_tm, world_top, offset)


func bake_closed_door_scene(generator: Node, scene: PackedScene, door_pos: Vector2, door_rot: float) -> int:
	var inst := scene.instantiate() as Node2D
	if inst == null:
		return 0

	generator.add_child(inst)

	# snap
	inst.global_position = door_pos
	inst.global_rotation = door_rot
	inst.force_update_transform()

	var tile_size := world_floor.tile_set.tile_size
	var tile_origin := Vector2i(
		int(round(inst.global_position.x / tile_size.x)),
		int(round(inst.global_position.y / tile_size.y))
	)

	var floor_tm := inst.get_node_or_null("TileMapLayer") as TileMapLayer
	var top_tm := inst.get_node_or_null("TopLayer") as TileMapLayer

	if floor_tm: _copy_layer(floor_tm, world_floor, tile_origin)
	if top_tm: _copy_layer(top_tm, world_top, tile_origin)

	inst.queue_free()
	return 1


func _copy_layer(src: TileMapLayer, dst: TileMapLayer, offset: Vector2i) -> void:
	for cell in src.get_used_cells():
		dst.set_cell(cell + offset,
			src.get_cell_source_id(cell),
			src.get_cell_atlas_coords(cell),
			src.get_cell_alternative_tile(cell)
		)
