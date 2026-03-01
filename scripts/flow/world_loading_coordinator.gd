extends RefCounted

var _main = null
var _world_load_flow: RefCounted = null


func configure(main_node, world_load_flow: RefCounted) -> void:
	_main = main_node
	_world_load_flow = world_load_flow


func setup_fog_layer_for_current_world() -> void:
	if _main == null:
		return
	if _main.fog_war_layer == null or _main.dungeon_floor == null or _main.world_root == null:
		return

	if _main.fog_war_layer.get_parent() != _main.world_root:
		var old_parent = _main.fog_war_layer.get_parent()
		if old_parent != null:
			old_parent.remove_child(_main.fog_war_layer)
		_main.world_root.add_child(_main.fog_war_layer)
		_main.fog_war_layer.position = _main.dungeon_floor.position

	var base_z := 0
	if _main.dungeon_top != null:
		base_z = _main.dungeon_top.z_index
	elif _main.dungeon_floor != null:
		base_z = _main.dungeon_floor.z_index
	_main.fog_war_layer.z_index = base_z + 10
	await init_fog_layer()


func init_fog_layer() -> void:
	if _main == null:
		return
	if _main.fog_war_layer == null or _main.dungeon_floor == null:
		return

	_main.fog_war_layer.clear()
	_main.fog_war_layer.tile_set = _main.dungeon_floor.tile_set
	_main.fog_war_layer.position = _main.dungeon_floor.position
	_main.fog_war_layer.visibility_layer = _main.dungeon_floor.visibility_layer

	var base_z = 0
	if _main.dungeon_top != null:
		base_z = _main.dungeon_top.z_index
	elif _main.dungeon_floor != null:
		base_z = _main.dungeon_floor.z_index
	_main.fog_war_layer.z_index = base_z + 10

	var counter = 0
	var used_rect = _main.dungeon_floor.get_used_rect()
	var yield_every = 300
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell = Vector2i(x, y)
			if _main.dungeon_floor.get_cell_source_id(cell) == -1:
				continue
			_main.fog_war_layer.set_cell(cell, 2, Vector2(2, 4), 0)
			counter += 1
			if counter % yield_every == 0:
				await _main.get_tree().process_frame


func clear_world() -> void:
	if _main == null:
		return

	if _main.battle_flow != null and _main.battle_flow.has_method("clear_battle"):
		_main.battle_flow.clear_battle()

	if _main.menu_instance != null and is_instance_valid(_main.menu_instance):
		_main.menu_instance.queue_free()
		_main.menu_instance = null

	if _main.player != null and is_instance_valid(_main.player):
		_main.player.queue_free()
		_main.player = null

	if _main.world_root != null and is_instance_valid(_main.world_root):
		if _main.fog_war_layer != null and is_instance_valid(_main.fog_war_layer):
			if _main.fog_war_layer.get_parent() == _main.world_root:
				_main.world_root.remove_child(_main.fog_war_layer)
				_main.add_child(_main.fog_war_layer)

		_main.world_root.queue_free()
		_main.world_root = null

	_main.dungeon_floor = null
	_main.dungeon_top = null

	if EntityAutoload != null and EntityAutoload.has_method("reset"):
		EntityAutoload.reset()

	if typeof(GlobalRNG) != TYPE_NIL and GlobalRNG != null and GlobalRNG.has_method("reset"):
		GlobalRNG.reset()


func _show_loading() -> void:
	if _main == null or _main.ui_overlay_coordinator == null:
		return
	_main.loading_screen = await _main.ui_overlay_coordinator.show_loading(
		_main, _main.LOADING_SCENE
	)


func _hide_loading() -> void:
	if _main == null or _main.ui_overlay_coordinator == null:
		return
	_main.ui_overlay_coordinator.hide_loading()
	_main.loading_screen = _main.ui_overlay_coordinator.get_loading_screen()


func load_tutorial_world(tutorial_room_path: String) -> void:
	if _main == null:
		return

	_main._set_tree_paused(true)
	await _show_loading()

	clear_world()
	_main.boss_win = false

	_main.world_root = Node2D.new()
	_main.world_root.name = "WorldRoot"
	_main.add_child(_main.world_root)

	var tutorial_packed = load(tutorial_room_path)
	if tutorial_packed == null:
		push_error("Failed to load tutorial room scene")
		_hide_loading()
		_main._set_tree_paused(false)
		return

	var tutorial_inst = tutorial_packed.instantiate()

	if tutorial_inst != null and tutorial_inst.has_method("get_random_tilemap"):
		var maps: Dictionary = await tutorial_inst.get_random_tilemap()

		if maps.is_empty():
			push_warning("Tutorial generator returned empty maps, falling back to scene extraction")
		else:
			_main.dungeon_floor = maps.get("floor", null)
			_main.dungeon_top = maps.get("top", null)
			_main.minimap = maps.get("minimap", null)

			if _main.dungeon_floor != null and _main.dungeon_floor.get_parent() == null:
				_main.world_root.add_child(_main.dungeon_floor)
			if _main.dungeon_top != null and _main.dungeon_top.get_parent() == null:
				_main.world_root.add_child(_main.dungeon_top)

			await setup_fog_layer_for_current_world()

			if _main.dungeon_floor != null:
				_main.dungeon_floor.visibility_layer = 1

			_main.player = await _main.spawn_coordinator.spawn_standard_world_entities(true, _main)

			_hide_loading()
			_main.get_tree().paused = false
			if is_instance_valid(tutorial_inst):
				tutorial_inst.queue_free()
			return

	var tutorial_scene = tutorial_inst as Node2D
	var extracted: Dictionary = {}
	if _world_load_flow != null:
		extracted = _world_load_flow.extract_tutorial_scene_to_world_root(
			tutorial_scene, _main.world_root
		)

	if extracted.is_empty() or not bool(extracted.get("ok", false)):
		push_error(str(extracted.get("error", "Failed to extract tutorial scene")))
		_hide_loading()
		_main._set_tree_paused(false)
		return

	_main.dungeon_floor = extracted.get("floor", null)
	_main.dungeon_top = extracted.get("top", _main.dungeon_floor)

	await setup_fog_layer_for_current_world()

	_main.dungeon_floor.visibility_layer = 1
	_main.player = await _main.spawn_coordinator.spawn_tutorial_entities_with_reveal(
		Callable(_main, "_on_player_moved"), _main
	)

	_hide_loading()
	_main._set_tree_paused(false)


func load_world(idx: int, generators: Array[Node2D]) -> void:
	if _main == null:
		return

	_main.world_index = idx
	if _main.game_event_gateway != null:
		_main.game_event_gateway.emit_world_loaded(idx)
	_main._set_tree_paused(true)
	await _show_loading()

	clear_world()

	if idx < 0 or idx >= generators.size():
		_hide_loading()
		_main._set_tree_paused(false)
		var scene_tree: SceneTree = _main.get_tree()
		if scene_tree != null:
			if typeof(_main.WIN_SCENE_PACKED) != TYPE_NIL:
				scene_tree.change_scene_to_packed(_main.WIN_SCENE_PACKED)
			else:
				scene_tree.change_scene_to_file(_main.WIN_SCENE)
		else:
			push_error("No more worlds left and SceneTree is null")
		return

	var gen = generators[idx]
	_main.ui_overlay_coordinator.bind_loading_to_generator(gen)

	_main.world_root = Node2D.new()
	_main.world_root.name = "WorldRoot"
	_main.add_child(_main.world_root)

	var entity_container = Node2D.new()
	entity_container.name = "Entities"
	_main.world_root.add_child(entity_container)
	entity_container.z_index = 3

	if (
		_main.saved_maps
		and typeof(_main.saved_maps) == TYPE_DICTIONARY
		and _main.saved_maps.has("floor")
	):
		_main.dungeon_floor = _main.saved_maps.get("floor", null)
		_main.dungeon_top = _main.saved_maps.get("top", null)
		_main.minimap = _main.saved_maps.get("minimap", null)
		if _world_load_flow != null:
			_world_load_flow.configure_saved_minimap(
				_main.minimap, _main.world_root, _main.dungeon_floor
			)
	elif not _main._should_load_from_save():
		var maps: Dictionary = await gen.get_random_tilemap()

		if maps.is_empty():
			push_error("Generator returned empty dictionary!")
			_hide_loading()
			_main._set_tree_paused(false)
			return
		_main.dungeon_floor = maps.get("floor", null)
		_main.dungeon_top = maps.get("top", null)
		_main.minimap = maps.get("minimap", null)
	else:
		push_error(
			"_load_world: requested load_from_save but no saved_maps available; falling back to generator"
		)
		var maps_fallback: Dictionary = await gen.get_random_tilemap()
		if maps_fallback.is_empty():
			push_error("Generator returned empty dictionary!")
			_hide_loading()
			_main._set_tree_paused(false)
			return
		_main.dungeon_floor = maps_fallback.get("floor", null)
		_main.dungeon_top = maps_fallback.get("top", null)
		_main.minimap = maps_fallback.get("minimap", null)

	if _main.dungeon_floor == null:
		push_error("Generator returned null floor tilemap!")
		_hide_loading()
		_main._set_tree_paused(false)
		return

	if _world_load_flow != null:
		_world_load_flow.apply_world_tileset_override(
			idx, _main.SEWER_TILESET, _main.dungeon_floor, _main.dungeon_top
		)
		_world_load_flow.attach_world_tilemaps(
			_main.world_root, _main.dungeon_floor, _main.dungeon_top
		)

	await setup_fog_layer_for_current_world()

	if _world_load_flow != null:
		_world_load_flow.add_minimap_background(_main.minimap, _main.backgroundtile)

	_main.dungeon_floor.visibility_layer = 1
	if (
		_main.saved_maps != null
		and typeof(_main.saved_maps) == TYPE_DICTIONARY
		and _main.saved_maps.has("entities")
	):
		if _main.persistence_coordinator != null:
			_main.persistence_coordinator.deserialize_entities(_main.saved_maps.get("entities", []))
		_main.saved_maps = {}
	else:
		_main.player = await _main.spawn_coordinator.spawn_standard_world_entities(true, _main)

	_hide_loading()
	_main._set_load_from_save(false)
	_main._set_tree_paused(false)
