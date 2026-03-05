extends RefCounted


func on_player_moved(
	minimap: Node,
	dungeon_floor: TileMapLayer,
	player: Node2D,
	fog_war_layer: TileMapLayer,
	scene_tree: SceneTree
) -> void:
	if minimap == null or dungeon_floor == null or player == null:
		return

	var world_cell: Vector2i = dungeon_floor.local_to_map(
		dungeon_floor.to_local(player.global_position)
	)

	for child in minimap.get_children():
		if not (child is TileMapLayer):
			continue

		var room_layer := child as TileMapLayer
		if room_layer.name == "MinimapBackground":
			continue

		var has_origin := room_layer.has_meta("tile_origin")
		var has_rect := room_layer.has_meta("room_rect")
		if not has_origin and not has_rect:
			continue

		var origin: Vector2i = room_layer.get_meta("tile_origin", Vector2i.ZERO)
		var local_cell := world_cell - origin

		if room_layer.get_cell_source_id(local_cell) != -1:
			if (
				typeof(AudioManager) != TYPE_NIL
				and AudioManager != null
				and AudioManager.has_method("set_in_boss_room")
			):
				AudioManager.set_in_boss_room(bool(room_layer.get_meta("is_boss_room", false)))

			room_layer.visible = true
			reveal_room_layer(room_layer, fog_war_layer, scene_tree)
			return

	if (
		typeof(AudioManager) != TYPE_NIL
		and AudioManager != null
		and AudioManager.has_method("set_in_boss_room")
	):
		AudioManager.set_in_boss_room(false)


func reveal_room_layer(
	room_layer: TileMapLayer, fog_war_layer: TileMapLayer, scene_tree: SceneTree
) -> void:
	if room_layer == null or fog_war_layer == null:
		return

	var origin: Vector2i = room_layer.get_meta("tile_origin", Vector2i.ZERO)
	var rect = room_layer.get_meta("room_rect", Rect2i(Vector2i.ZERO, Vector2i.ZERO))
	if rect.size == Vector2i.ZERO:
		for cell in room_layer.get_used_cells():
			var world_cell = origin + cell
			fog_war_layer.erase_cell(world_cell)
		return

	var counter = 0
	var yield_every = 300
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_cell = Vector2i(x, y)
			if room_layer.get_cell_source_id(local_cell) == -1:
				continue
			var world_cell = origin + local_cell
			fog_war_layer.erase_cell(world_cell)
			counter += 1
			if counter % yield_every == 0 and scene_tree != null:
				await scene_tree.process_frame
