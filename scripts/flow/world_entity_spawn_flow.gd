extends RefCounted


func _has_custom_data_layer(tile_set: TileSet, layer_name: String) -> bool:
	if tile_set == null:
		return false

	var layer_count = tile_set.get_custom_data_layers_count()
	for i in range(layer_count):
		if tile_set.get_custom_data_layer_name(i) == layer_name:
			return true

	return false


func spawn_merchant_entity(
	cords: Vector2,
	merchant_scene: PackedScene,
	world_root: Node,
	fallback_parent: Node,
	world_index: int
) -> void:
	if merchant_scene == null:
		return

	var entity = merchant_scene.instantiate()
	entity.add_to_group("merchant_entity")
	entity.global_position = cords

	if entity.has_method("set"):
		var merchant_id = (
			"merchant_%d_%d_world%d"
			% [
				int(cords.x),
				int(cords.y),
				int(world_index),
			]
		)
		entity.set("merchant_id", merchant_id)
		entity.set("merchant_room", "merchant_room")

	if world_root != null:
		world_root.add_child(entity)
	elif fallback_parent != null:
		fallback_parent.add_child(entity)


func spawn_traps(
	dungeon_floor: TileMapLayer, world_root: Node, trap_scene: PackedScene, world_index: int
) -> void:
	if dungeon_floor == null or world_root == null or trap_scene == null:
		return

	var tile_set = dungeon_floor.tile_set
	if tile_set == null:
		return

	if not _has_custom_data_layer(tile_set, "trap_spawnable"):
		push_warning("TileSet has no custom data layer 'trap_spawnable'. Skipping trap spawns.")
		return

	for child in world_root.get_children():
		if child != null and child.name.begins_with("Trap"):
			child.queue_free()

	var candidates: Array[Vector2i] = []
	for cell in dungeon_floor.get_used_cells():
		var tile_data = dungeon_floor.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		if tile_data.get_custom_data("trap_spawnable") == true:
			candidates.append(cell)

	if candidates.is_empty():
		return

	GlobalRNG.shuffle_array(candidates)
	var amount = min(20, candidates.size())

	for i in range(amount):
		var spawn_cell = candidates[i]
		var world_pos = dungeon_floor.to_global(dungeon_floor.map_to_local(spawn_cell))

		var trap = trap_scene.instantiate() as Node2D
		trap.name = "Trap_%s" % i
		if trap.has_method("set"):
			trap.set("world_index", world_index)
		world_root.add_child(trap)
		trap.global_position = world_pos


func spawn_lootbox(
	dungeon_floor: TileMapLayer, world_root: Node, lootbox_scene: PackedScene
) -> void:
	if dungeon_floor == null or world_root == null or lootbox_scene == null:
		return

	var tile_set = dungeon_floor.tile_set
	if tile_set == null:
		return

	if not _has_custom_data_layer(tile_set, "lootbox_spawnable"):
		push_warning(
			"TileSet has no custom data layer 'lootbox_spawnable'. Skipping lootbox spawns."
		)
		return

	for child in world_root.get_children():
		if child != null and child.name.begins_with("Lootbox"):
			child.queue_free()

	var candidates: Array[Vector2i] = []
	for cell in dungeon_floor.get_used_cells():
		var tile_data = dungeon_floor.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		if tile_data.get_custom_data("lootbox_spawnable") == true:
			candidates.append(cell)

	if candidates.is_empty():
		return

	GlobalRNG.shuffle_array(candidates)
	var amount = min(20, candidates.size())

	for i in range(amount):
		var spawn_cell = candidates[i]
		var world_pos = dungeon_floor.to_global(dungeon_floor.map_to_local(spawn_cell))

		var loot = lootbox_scene.instantiate() as Node2D
		loot.name = "Lootbox_%s" % i
		if loot.has_method("set"):
			loot.set("lootbox_id", "lootbox_%s" % i)
		world_root.add_child(loot)
		loot.global_position = world_pos


func find_merchants(dungeon_floor: TileMapLayer) -> Array[Vector2]:
	var merchants: Array[Vector2] = []
	if dungeon_floor == null:
		return merchants

	for cell in dungeon_floor.get_used_cells():
		var data = dungeon_floor.get_cell_tile_data(cell)
		if data == null:
			continue
		if not data.get_custom_data("merchant"):
			continue

		var right = cell + Vector2i(1, 0)
		var right_data = dungeon_floor.get_cell_tile_data(right)
		if right_data and right_data.get_custom_data("merchant"):
			var left_pos = dungeon_floor.map_to_local(cell)
			var right_pos = dungeon_floor.map_to_local(right)
			merchants.append((left_pos + right_pos) * 0.5)

	return merchants
