extends RefCounted

const MAX_WORLD_SPAWNS_PER_TYPE := 20


func _clear_existing_spawns(world_root: Node, name_prefix: String) -> void:
	if world_root == null:
		return
	for child in world_root.get_children():
		if child != null and child.name.begins_with(name_prefix):
			child.queue_free()


func _collect_spawn_candidates(
	dungeon_floor: TileMapLayer, custom_data_key: String, missing_layer_warning: String
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	if dungeon_floor == null:
		return candidates

	var tile_set = dungeon_floor.tile_set
	if tile_set == null:
		return candidates

	if not _has_custom_data_layer(tile_set, custom_data_key):
		push_warning(missing_layer_warning)
		return candidates

	for cell in dungeon_floor.get_used_cells():
		var tile_data = dungeon_floor.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		if tile_data.get_custom_data(custom_data_key) == true:
			candidates.append(cell)

	return candidates


func _spawn_from_candidates(
	candidates: Array[Vector2i],
	dungeon_floor: TileMapLayer,
	world_root: Node,
	scene: PackedScene,
	name_prefix: String,
	configure_spawn: Callable
) -> void:
	if candidates.is_empty() or dungeon_floor == null or world_root == null or scene == null:
		return

	GlobalRNG.shuffle_array(candidates)
	var amount = min(MAX_WORLD_SPAWNS_PER_TYPE, candidates.size())

	for i in range(amount):
		var spawn_cell = candidates[i]
		var world_pos = dungeon_floor.to_global(dungeon_floor.map_to_local(spawn_cell))

		var spawned_node = scene.instantiate() as Node2D
		spawned_node.name = "%s_%s" % [name_prefix, i]
		world_root.add_child(spawned_node)
		spawned_node.global_position = world_pos

		if configure_spawn.is_valid():
			configure_spawn.call(spawned_node, i)


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

	_clear_existing_spawns(world_root, "Trap")

	var candidates := _collect_spawn_candidates(
		dungeon_floor,
		"trap_spawnable",
		"TileSet has no custom data layer 'trap_spawnable'. Skipping trap spawns."
	)

	_spawn_from_candidates(
		candidates,
		dungeon_floor,
		world_root,
		trap_scene,
		"Trap",
		func(spawned_node: Node2D, _index: int):
			if spawned_node.has_method("set"):
				spawned_node.set("world_index", world_index)
	)


func spawn_lootbox(
	dungeon_floor: TileMapLayer, world_root: Node, lootbox_scene: PackedScene
) -> void:
	if dungeon_floor == null or world_root == null or lootbox_scene == null:
		return

	_clear_existing_spawns(world_root, "Lootbox")

	var candidates := _collect_spawn_candidates(
		dungeon_floor,
		"lootbox_spawnable",
		"TileSet has no custom data layer 'lootbox_spawnable'. Skipping lootbox spawns."
	)

	_spawn_from_candidates(
		candidates,
		dungeon_floor,
		world_root,
		lootbox_scene,
		"Lootbox",
		func(spawned_node: Node2D, index: int):
			if spawned_node.has_method("set"):
				spawned_node.set("lootbox_id", "lootbox_%s" % index)
	)


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
