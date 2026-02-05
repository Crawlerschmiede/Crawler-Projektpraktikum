# Baking / Tilemap helpers

class_name MGBake

const MGIO = preload("res://scripts/Mapgenerator/helpers/mg_io.gd")
const MGCOL = preload("res://scripts/Mapgenerator/helpers/mg_collision.gd")


func copy_layer_into_world(
	gen,
	src: TileMapLayer,
	dst: TileMapLayer,
	offset: Vector2i,
	emit_start: float = -1.0,
	emit_end: float = -1.0,
	emit_text: String = ""
) -> void:
	var counter = 0
	var cells = src.get_used_cells()
	var total = cells.size()
	var emit_every = 100
	var yield_every = 100
	for idx in range(total):
		var cell = cells[idx]
		var source_id = src.get_cell_source_id(cell)
		var atlas = src.get_cell_atlas_coords(cell)
		var alt = src.get_cell_alternative_tile(cell)
		dst.set_cell(cell + offset, source_id, atlas, alt)
		counter += 1
		if total > 0 and emit_start >= 0.0 and counter % emit_every == 0:
			var local_p = float(counter) / float(total)
			# prefer calling generator progress if provided, otherwise try dst parent
			if gen != null and gen.has_method("_emit_progress_mapped"):
				gen._emit_progress_mapped(emit_start, emit_end, clamp(local_p, 0.0, 1.0), emit_text)
			elif dst.get_parent() != null and dst.get_parent().has_method("_emit_progress_mapped"):
				dst.get_parent()._emit_progress_mapped(
					emit_start, emit_end, clamp(local_p, 0.0, 1.0), emit_text
				)
		if counter % yield_every == 0:
			await _safe_process_frame(gen, dst)
	if emit_start >= 0.0:
		if gen != null and gen.has_method("_emit_progress_mapped"):
			gen._emit_progress_mapped(emit_start, emit_end, 1.0, emit_text)
		elif dst.get_parent() != null and dst.get_parent().has_method("_emit_progress_mapped"):
			dst.get_parent()._emit_progress_mapped(emit_start, emit_end, 1.0, emit_text)


func add_room_layer_to_minimap(gen, room: Node2D) -> void:
	if gen.minimap == null:
		return
	var floor_tm = room.get_node_or_null("TileMapLayer") as TileMapLayer
	if floor_tm == null:
		return
	if gen.minimap.tile_set == null:
		gen.minimap.tile_set = floor_tm.tile_set
	var origin: Vector2i = room.get_meta("tile_origin", Vector2i.ZERO)
	var layer_name = "Room_%s_%s" % [origin.x, origin.y]
	if gen.minimap.has_node(layer_name):
		return
	var room_layer = TileMapLayer.new()
	room_layer.name = layer_name
	room_layer.tile_set = floor_tm.tile_set
	room_layer.visible = false
	room_layer.visibility_layer = 1 << 1
	room_layer.set_meta("room_rect", floor_tm.get_used_rect())
	room_layer.set_meta("tile_origin", origin)
	var tile_size: Vector2i = floor_tm.tile_set.tile_size
	room_layer.position = Vector2(origin.x * tile_size.x, origin.y * tile_size.y)
	gen.minimap.add_child(room_layer)
	var counter = 0
	for cell in floor_tm.get_used_cells():
		var source_id = floor_tm.get_cell_source_id(cell)
		var atlas = floor_tm.get_cell_atlas_coords(cell)
		var alt = floor_tm.get_cell_alternative_tile(cell)
		room_layer.set_cell(cell, source_id, atlas, alt)
		counter += 1
		if counter % gen.yield_frame_chunk == 0:
			await _safe_process_frame(gen, null)


func _safe_process_frame(gen: Node, alt: Node) -> void:
	# Try generator's SceneTree first, then alt node, then Engine main loop
	var st: SceneTree = null
	if gen != null and gen.get_tree() != null:
		st = gen.get_tree()
	elif alt != null and alt.get_tree() != null:
		st = alt.get_tree()
	else:
		st = Engine.get_main_loop() as SceneTree
	if st != null:
		await st.process_frame


func bake_rooms_into_world_tilemap(gen) -> void:
	if gen.placed_rooms.is_empty():
		push_error("❌ [BAKE] Keine Räume zum Baken vorhanden")
		return
	if gen.world_tilemap == null:
		gen.world_tilemap = TileMapLayer.new()
		gen.world_tilemap.name = "WorldFloor"
		var first_floor = gen.placed_rooms[0].get_node_or_null("TileMapLayer") as TileMapLayer
		if first_floor == null:
			push_error("❌ [BAKE] StartRoom hat keine TileMapLayer (Floor)")
			return
		gen.world_tilemap.tile_set = first_floor.tile_set
	if gen.world_tilemap_top == null:
		gen.world_tilemap_top = TileMapLayer.new()
		gen.world_tilemap_top.name = "WorldTop"
		var first_top = gen.placed_rooms[0].get_node_or_null("TopLayer") as TileMapLayer
		if first_top != null:
			gen.world_tilemap_top.tile_set = first_top.tile_set
		else:
			gen.world_tilemap_top.tile_set = gen.world_tilemap.tile_set
	gen.world_tilemap.clear()
	gen.world_tilemap_top.clear()
	var total_rooms = gen.placed_rooms.size()
	var i = 0
	for room in gen.placed_rooms:
		var floor_tm = room.get_node_or_null("TileMapLayer") as TileMapLayer
		var top_tm = room.get_node_or_null("TopLayer") as TileMapLayer
		var room_offset: Vector2i = room.get_meta("tile_origin", Vector2i.ZERO)
		if floor_tm != null:
			await add_room_layer_to_minimap(gen, room)
			await copy_layer_into_world(
				gen, floor_tm, gen.world_tilemap, room_offset, 0.75, 0.92, "Building tilemaps"
			)
			i += 1
			if total_rooms > 0:
				var local_p = float(i) / float(total_rooms)
				gen._emit_progress_mapped(
					0.75,
					0.92,
					clamp(local_p, 0.0, 1.0),
					"Building tilemaps: %d/%d" % [i, total_rooms]
				)
				await gen.get_tree().process_frame
		if top_tm != null:
			await copy_layer_into_world(
				gen, top_tm, gen.world_tilemap_top, room_offset, 0.75, 0.92, "Building tilemaps"
			)
	gen._emit_progress_mapped(0.92, 0.98, 0.0, "Baking doors...")
	await gen.get_tree().process_frame
	await bake_closed_doors_into_world_simple(gen)
	await bake_closed_doors_into_minimap(gen)
	gen._emit_progress_mapped(0.92, 0.98, 1.0, "Baking doors...")
	await gen.get_tree().process_frame
	gen._emit_progress_mapped(0.98, 1.0, 1.0, "Done")
	await gen.get_tree().process_frame


func bake_closed_doors_into_world_simple(gen) -> void:
	if gen.world_tilemap == null:
		push_error("world_tilemap ist null!")
		return
	var tile_size = gen.world_tilemap.tile_set.tile_size
	var total = 0
	for r in gen.placed_rooms:
		if r == null or not r.has_method("get_free_doors"):
			continue
		for d in r.get_free_doors():
			if d == null or d.used:
				continue
			total += 1
	var processed = 0
	for room in gen.placed_rooms:
		if room == null or not room.has_method("get_free_doors"):
			continue
		for door in room.get_free_doors():
			if door == null or door.used:
				continue
			var door_scene = gen.get_closed_door_for_direction(str(door.direction))
			if door_scene == null:
				continue
			var inst = door_scene.instantiate() as Node2D
			gen.add_child(inst)
			inst.global_position = door.global_position
			inst.force_update_transform()
			var tile_origin = Vector2i(
				int(round(inst.global_position.x / tile_size.x)),
				int(round(inst.global_position.y / tile_size.y))
			)
			var src_floor = inst.get_node_or_null("TileMapLayer") as TileMapLayer
			var src_top = inst.get_node_or_null("TopLayer") as TileMapLayer
			if src_floor != null:
				await copy_layer_into_world(
					gen, src_floor, gen.world_tilemap, tile_origin, 0.92, 0.98, "Baking doors"
				)
			if src_top != null:
				await copy_layer_into_world(
					gen, src_top, gen.world_tilemap_top, tile_origin, 0.92, 0.98, "Baking doors"
				)
			inst.queue_free()
			door.used = true
			processed += 1


func bake_closed_doors_into_minimap(gen) -> void:
	if gen.minimap == null or gen.world_tilemap == null:
		return
	var tile_size = gen.world_tilemap.tile_set.tile_size
	for room in gen.placed_rooms:
		if room == null or not room.has_method("get_free_doors"):
			continue
		for door in room.get_free_doors():
			if door == null:
				continue
			var door_scene = gen.get_closed_door_for_direction(str(door.direction))
			if door_scene == null:
				continue
			var inst = door_scene.instantiate() as Node2D
			gen.add_child(inst)
			inst.global_position = door.global_position
			inst.force_update_transform()
			var world_cell = Vector2i(
				int(round(inst.global_position.x / tile_size.x)),
				int(round(inst.global_position.y / tile_size.y))
			)
			var src_floor = inst.get_node_or_null("TileMapLayer") as TileMapLayer
			if src_floor == null:
				inst.queue_free()
				continue
			var target_layer: TileMapLayer = null
			var target_origin: Vector2i = Vector2i.ZERO
			for child in gen.minimap.get_children():
				if not (child is TileMapLayer):
					continue
				var layer = child as TileMapLayer
				var origin: Vector2i = layer.get_meta("tile_origin", Vector2i.ZERO)
				var rect: Rect2i = layer.get_meta("room_rect", Rect2i())
				var local_cell = world_cell - origin
				if rect.has_point(local_cell):
					target_layer = layer
					target_origin = origin
					break
			if target_layer == null:
				inst.queue_free()
				continue
			var offset = world_cell - target_origin
			var counter = 0
			var cells = src_floor.get_used_cells()
			var ctotal = cells.size()
			for cidx in range(ctotal):
				var cell = cells[cidx]
				var source_id = src_floor.get_cell_source_id(cell)
				var atlas = src_floor.get_cell_atlas_coords(cell)
				var alt = src_floor.get_cell_alternative_tile(cell)
				target_layer.set_cell(cell + offset, source_id, atlas, alt)
				counter += 1
				if counter % gen.yield_frame_chunk == 0:
					await gen._yield_if_needed(gen.yield_frame_chunk)
			inst.queue_free()
