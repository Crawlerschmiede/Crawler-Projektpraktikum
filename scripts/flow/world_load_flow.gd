extends RefCounted


func configure_saved_minimap(
	minimap: Node, world_root: Node2D, dungeon_floor: TileMapLayer
) -> void:
	if minimap == null or world_root == null or dungeon_floor == null:
		return

	if minimap.get_parent() != world_root:
		world_root.add_child(minimap)

	minimap.position = dungeon_floor.position
	minimap.z_index = -50
	minimap.visibility_layer = 1 << 1

	for child in minimap.get_children():
		if child is TileMapLayer:
			var layer := child as TileMapLayer
			if layer.name == "MinimapBackground":
				layer.visible = true
				continue
			if layer.has_meta("tile_origin") or layer.has_meta("room_rect"):
				layer.visible = false


func apply_world_tileset_override(
	world_index: int,
	sewer_tileset_path: String,
	dungeon_floor: TileMapLayer,
	dungeon_top: TileMapLayer
) -> void:
	if world_index != 1:
		return
	if dungeon_floor == null:
		return

	var sewer_tileset = load(sewer_tileset_path) as TileSet
	if sewer_tileset != null:
		dungeon_floor.tile_set = sewer_tileset
		if dungeon_top != null:
			dungeon_top.tile_set = sewer_tileset


func attach_world_tilemaps(
	world_root: Node2D, dungeon_floor: TileMapLayer, dungeon_top: TileMapLayer
) -> void:
	if world_root == null or dungeon_floor == null:
		return

	dungeon_floor.owner = world_root
	if dungeon_top != null:
		dungeon_top.owner = world_root

	if dungeon_floor.get_parent() == null:
		world_root.add_child(dungeon_floor)
	dungeon_floor.z_index = 0

	if dungeon_top != null:
		if dungeon_top.get_parent() == null:
			world_root.add_child(dungeon_top)
		dungeon_top.z_index = 1


func add_minimap_background(minimap: Node, backgroundtile: TileMapLayer) -> void:
	if minimap == null or backgroundtile == null:
		return

	var bg = backgroundtile.duplicate() as TileMapLayer
	bg.set_meta("is_background", true)
	bg.visible = true
	bg.name = "MinimapBackground"
	bg.visibility_layer = 1 << 1
	bg.z_index = -100
	minimap.add_child(bg)
	minimap.move_child(bg, -1)


func extract_tutorial_scene_to_world_root(tutorial_scene: Node2D, world_root: Node2D) -> Dictionary:
	if tutorial_scene == null:
		return {"ok": false, "error": "Failed to load tutorial scene!"}
	if world_root == null:
		return {"ok": false, "error": "World root is null"}

	var tilemaps = tutorial_scene.find_children("*", "TileMapLayer")
	if tilemaps.is_empty():
		return {"ok": false, "error": "Tutorial scene has no TileMapLayer!"}

	var dungeon_floor = tilemaps[0] as TileMapLayer
	var dungeon_top: TileMapLayer = null

	if tilemaps.size() > 1:
		for tm in tilemaps:
			if tm.name.to_lower().contains("tile"):
				dungeon_floor = tm as TileMapLayer
			elif tm.name.to_lower().contains("top"):
				dungeon_top = tm as TileMapLayer

		if dungeon_top == null and tilemaps.size() > 1:
			dungeon_top = tilemaps[1] as TileMapLayer
	else:
		dungeon_top = dungeon_floor

	for tm in tilemaps:
		if tm.get_parent() != null:
			tm.get_parent().remove_child(tm)
		world_root.add_child(tm)
		tm.position = Vector2.ZERO

	var area2ds = tutorial_scene.find_children("*", "Area2D")
	for area in area2ds:
		if area.get_parent() != null:
			area.get_parent().remove_child(area)
		world_root.add_child(area)

	var canvas_modulates = tutorial_scene.find_children("*", "CanvasModulate")
	for canvas_modulate in canvas_modulates:
		if canvas_modulate.get_parent() != null:
			canvas_modulate.get_parent().remove_child(canvas_modulate)
		world_root.add_child(canvas_modulate)

	var physics_bodies = tutorial_scene.find_children("*", "PhysicsBody2D")
	for body in physics_bodies:
		if body.get_parent() != null:
			body.get_parent().remove_child(body)
		world_root.add_child(body)
		body.position = Vector2.ZERO

	tutorial_scene.queue_free()

	return {
		"ok": true,
		"floor": dungeon_floor,
		"top": dungeon_top,
	}
