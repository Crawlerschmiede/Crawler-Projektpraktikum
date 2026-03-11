extends RefCounted

const PLAYER_Z_INDEX_OFFSET := 10000000

var _main = null
var _world_entity_spawn_flow: RefCounted = null
var _enemy_spawn_flow: RefCounted = null


func configure(
	main_node, world_entity_spawn_flow: RefCounted, enemy_spawn_flow: RefCounted
) -> void:
	_main = main_node
	_world_entity_spawn_flow = world_entity_spawn_flow
	_enemy_spawn_flow = enemy_spawn_flow


func spawn_merchant_entity(cords: Vector2, merchant_scene: PackedScene, world_index: int) -> void:
	if _world_entity_spawn_flow == null or _main == null:
		return
	_world_entity_spawn_flow.spawn_merchant_entity(
		cords, merchant_scene, _main.world_root, _main, world_index
	)


func spawn_traps(dungeon_floor: TileMapLayer, trap_scene: PackedScene, world_index: int) -> void:
	if _world_entity_spawn_flow == null or _main == null:
		return
	_world_entity_spawn_flow.spawn_traps(dungeon_floor, _main.world_root, trap_scene, world_index)


func spawn_lootbox(dungeon_floor: TileMapLayer, lootbox_scene: PackedScene) -> void:
	if _world_entity_spawn_flow == null or _main == null:
		return
	_world_entity_spawn_flow.spawn_lootbox(dungeon_floor, _main.world_root, lootbox_scene)


func spawn_enemies(
	do_boss: bool,
	world_index: int,
	dungeon_floor: TileMapLayer,
	dungeon_top: TileMapLayer,
	owner,
	boss_spawn_weight_override: int = -1
) -> void:
	if _enemy_spawn_flow == null or _main == null:
		return

	var data: Dictionary = EntityAutoload.item_data
	_enemy_spawn_flow.spawn_enemies(
		do_boss,
		world_index,
		data,
		dungeon_floor,
		dungeon_top,
		_main.world_root,
		owner,
		boss_spawn_weight_override
	)


func spawn_enemy(
	sprite_type: String,
	behaviour: Array,
	skills: Array,
	stats: Dictionary,
	xp: int,
	dungeon_floor: TileMapLayer,
	dungeon_top: TileMapLayer,
	owner,
	boss: bool = false
) -> void:
	if _enemy_spawn_flow == null or _main == null:
		return
	skills.append("Extinguish")
	_enemy_spawn_flow.spawn_enemy(
		sprite_type,
		behaviour,
		skills,
		stats,
		xp,
		dungeon_floor,
		dungeon_top,
		_main.world_root,
		owner,
		boss
	)


func spawn_player(
	player_scene: PackedScene,
	dungeon_floor: TileMapLayer,
	dungeon_top: TileMapLayer,
	fog_war_layer: TileMapLayer,
	minimap: TileMapLayer,
	fog_dynamic: bool,
	fog_tile_id: int,
	entity_persistence_flow: RefCounted,
	owner,
	spawn_pos_override: Variant = null
):
	if _main == null or _main.world_root == null or player_scene == null or dungeon_floor == null:
		return null

	for n in _main.get_tree().get_nodes_in_group("player"):
		if n != null and is_instance_valid(n):
			n.queue_free()

	var e = player_scene.instantiate()
	e.name = "Player"
	e.setup(dungeon_floor, dungeon_top, 10, 3, 0, {})
	e.fog_layer = fog_war_layer
	if e.has_method("set"):
		e.set("dynamic_fog", fog_dynamic)
		e.set("fog_tile_id", fog_tile_id)
	_main.world_root.add_child(e)

	if fog_war_layer != null:
		e.z_index = fog_war_layer.z_index + PLAYER_Z_INDEX_OFFSET

	if minimap != null and is_instance_valid(minimap):
		e.set_minimap(minimap)
	else:
		e.set_minimap(null)

	var start_pos = Vector2i(2, 2)
	if typeof(spawn_pos_override) == TYPE_VECTOR2I:
		start_pos = spawn_pos_override
	elif minimap == null:
		start_pos = Vector2i(-18, 15)

	e.grid_pos = start_pos
	e.global_position = dungeon_floor.to_global(dungeon_floor.map_to_local(start_pos))
	e.add_to_group("player")

	if entity_persistence_flow != null:
		entity_persistence_flow.connect_player_signals(owner, e, true)

	if e.has_method("update_visibility") and entity_persistence_flow != null:
		entity_persistence_flow.update_player_visibility(e)
		owner.emit_signal("player_spawned", e)

	return e


func find_merchants(dungeon_floor: TileMapLayer) -> Array[Vector2]:
	if _world_entity_spawn_flow == null:
		return []
	return _world_entity_spawn_flow.find_merchants(dungeon_floor)


func spawn_standard_world_entities(include_boss_enemy: bool, owner):
	if _main == null:
		return null

	var spawned_player = spawn_player(
		_main.PLAYER_SCENE,
		_main.dungeon_floor,
		_main.dungeon_top,
		_main.fog_war_layer,
		_main.minimap,
		_main.fog_dynamic,
		_main.fog_tile_id,
		_main.entity_persistence_flow,
		owner
	)

	spawn_enemies(false, _main.world_index, _main.dungeon_floor, _main.dungeon_top, owner)
	spawn_lootbox(_main.dungeon_floor, _main.LOOTBOX)
	spawn_traps(_main.dungeon_floor, _main.TRAP, _main.world_index)
	if include_boss_enemy:
		spawn_enemies(true, _main.world_index, _main.dungeon_floor, _main.dungeon_top, owner)

	var merchants = find_merchants(_main.dungeon_floor)
	for i in merchants:
		spawn_merchant_entity(i, _main.MERCHANT, _main.world_index)

	return spawned_player


func spawn_tutorial_entities_with_reveal(on_player_moved: Callable, owner):
	if _main == null:
		return null

	var spawned_player = spawn_player(
		_main.PLAYER_SCENE,
		_main.dungeon_floor,
		_main.dungeon_top,
		_main.fog_war_layer,
		_main.minimap,
		_main.fog_dynamic,
		_main.fog_tile_id,
		_main.entity_persistence_flow,
		owner
	)
	spawn_enemies(false, _main.world_index, _main.dungeon_floor, _main.dungeon_top, owner)
	spawn_lootbox(_main.dungeon_floor, _main.LOOTBOX)
	spawn_traps(_main.dungeon_floor, _main.TRAP, _main.world_index)

	var tree: SceneTree = _main.get_tree()
	if tree != null:
		await tree.process_frame
		await tree.process_frame

	if on_player_moved.is_valid():
		on_player_moved.call()

	var merchants = find_merchants(_main.dungeon_floor)
	for i in merchants:
		spawn_merchant_entity(i, _main.MERCHANT, _main.world_index)

	return spawned_player


func spawn_final_boss_world_entities(owner):
	if _main == null:
		return null

	var spawned_player = spawn_player(
		_main.PLAYER_SCENE,
		_main.dungeon_floor,
		_main.dungeon_top,
		_main.fog_war_layer,
		_main.minimap,
		_main.fog_dynamic,
		_main.fog_tile_id,
		_main.entity_persistence_flow,
		owner,
		Vector2i(0, 12)
	)

	# Final boss world: only spawn boss enemy, no lootboxes/traps/merchants/regular enemies.
	spawn_enemies(
		true,
		_main.world_index,
		_main.dungeon_floor,
		_main.dungeon_top,
		owner,
		2
	)

	return spawned_player
