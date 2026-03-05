extends RefCounted


func serialize_tilemap(tm: TileMapLayer) -> Dictionary:
	if tm == null:
		return {}

	var out: Dictionary = {}
	out["name"] = str(tm.name)
	out["position"] = [float(tm.position.x), float(tm.position.y)]
	out["z_index"] = int(tm.z_index)
	out["visibility_layer"] = int(tm.visibility_layer)

	out["tile_set"] = ""
	if tm.tile_set != null and tm.tile_set.resource_path != "":
		out["tile_set"] = str(tm.tile_set.resource_path)

	out["meta"] = {}
	if tm.has_meta("tile_origin"):
		var to: Vector2i = tm.get_meta("tile_origin")
		out["meta"]["tile_origin"] = [int(to.x), int(to.y)]
	if tm.has_meta("room_rect"):
		var rr: Rect2i = tm.get_meta("room_rect")
		out["meta"]["room_rect"] = {
			"pos": [int(rr.position.x), int(rr.position.y)],
			"size": [int(rr.size.x), int(rr.size.y)]
		}

	out["cells"] = []
	for cell in tm.get_used_cells():
		var atlas: Vector2i = tm.get_cell_atlas_coords(cell)
		var item = {
			"x": int(cell.x),
			"y": int(cell.y),
			"source_id": int(tm.get_cell_source_id(cell)),
			"atlas": [int(atlas.x), int(atlas.y)],
			"alt": int(tm.get_cell_alternative_tile(cell)),
		}
		out["cells"].append(item)

	return out


func deserialize_tilemap(data: Dictionary) -> TileMapLayer:
	if data == null or typeof(data) != TYPE_DICTIONARY or data.is_empty():
		return null

	var tm = TileMapLayer.new()
	tm.clear()

	var ts_path = str(data.get("tile_set", ""))
	if ts_path != "":
		var ts = load(ts_path)
		if ts != null and ts is TileSet:
			tm.tile_set = ts

	tm.name = str(data.get("name", "TileMapLayer"))
	var pos_arr = data.get("position", [0.0, 0.0])
	if typeof(pos_arr) == TYPE_ARRAY and pos_arr.size() >= 2:
		tm.position = Vector2(float(pos_arr[0]), float(pos_arr[1]))

	tm.z_index = int(data.get("z_index", 0))
	tm.visibility_layer = int(data.get("visibility_layer", 1))

	var meta = data.get("meta", {})
	if typeof(meta) == TYPE_DICTIONARY:
		if meta.has("tile_origin"):
			var to = meta.get("tile_origin", [0, 0])
			if typeof(to) == TYPE_ARRAY and to.size() >= 2:
				tm.set_meta("tile_origin", Vector2i(int(to[0]), int(to[1])))
		if meta.has("room_rect"):
			var rr = meta.get("room_rect", {})
			if typeof(rr) == TYPE_DICTIONARY:
				var p = rr.get("pos", [0, 0])
				var s = rr.get("size", [0, 0])
				if (
					typeof(p) == TYPE_ARRAY
					and p.size() >= 2
					and typeof(s) == TYPE_ARRAY
					and s.size() >= 2
				):
					tm.set_meta(
						"room_rect",
						Rect2i(Vector2i(int(p[0]), int(p[1])), Vector2i(int(s[0]), int(s[1])))
					)

	var cells = data.get("cells", [])
	if typeof(cells) == TYPE_ARRAY:
		for item in cells:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var x = int(item.get("x", 0))
			var y = int(item.get("y", 0))
			var source_id = int(item.get("source_id", -1))
			if source_id == -1:
				continue

			var atlas = item.get("atlas", [0, 0])
			var atlas_vec = Vector2i(0, 0)
			if typeof(atlas) == TYPE_ARRAY and atlas.size() >= 2:
				atlas_vec = Vector2i(int(atlas[0]), int(atlas[1]))

			var alt = int(item.get("alt", 0))
			tm.set_cell(Vector2i(x, y), source_id, atlas_vec, alt)

	return tm


func serialize_minimap(minimap_node: Node) -> Dictionary:
	if minimap_node == null:
		return {}

	if minimap_node is TileMapLayer:
		return {"type": "single", "tilemap": serialize_tilemap(minimap_node)}

	var out: Dictionary = {"type": "group", "children": []}
	for child in minimap_node.get_children():
		if child is TileMapLayer:
			out["children"].append(serialize_tilemap(child))

	return out


func deserialize_minimap(data: Dictionary) -> Node:
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return null
	if str(data.get("type", "")) == "single":
		var tm_data = data.get("tilemap", {})
		return deserialize_tilemap(tm_data)

	var root = Node2D.new()
	root.name = "Minimap"
	var children = data.get("children", [])
	for cd in children:
		var tm = deserialize_tilemap(cd)
		if tm != null:
			root.add_child(tm)

	return root
