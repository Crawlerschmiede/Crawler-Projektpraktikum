extends RefCounted

var _main = null
var _save_flow: RefCounted = null
var _save_serializer: RefCounted = null
var _entity_persistence_flow: RefCounted = null


func configure(
	main_node,
	save_flow: RefCounted,
	save_serializer: RefCounted,
	entity_persistence_flow: RefCounted
) -> void:
	_main = main_node
	_save_flow = save_flow
	_save_serializer = save_serializer
	_entity_persistence_flow = entity_persistence_flow


func serialize_entities() -> Array:
	if _entity_persistence_flow == null:
		return []
	return _entity_persistence_flow.serialize_entities(_main.world_root)


func deserialize_entities(list_data: Array) -> void:
	if _entity_persistence_flow == null:
		return
	if _main.world_root == null:
		push_error("_deserialize_entities: world_root is null")
		return

	var scenes: Dictionary = {
		"enemy": _main.ENEMY_SCENE,
		"merchant": _main.MERCHANT,
		"lootbox": _main.LOOTBOX,
		"trap": _main.TRAP,
		"player": _main.PLAYER_SCENE,
	}
	var defaults: Dictionary = {
		"fog_dynamic": _main.fog_dynamic,
		"fog_tile_id": _main.fog_tile_id,
	}

	var loaded_player: Node = _entity_persistence_flow.deserialize_entities(
		list_data,
		_main.world_root,
		_main.dungeon_floor,
		_main.dungeon_top,
		_main.fog_war_layer,
		_main.minimap,
		scenes,
		defaults,
		_main
	)

	if loaded_player is PlayerCharacter:
		_main.player = loaded_player as PlayerCharacter


func save_current_world() -> void:
	if _save_flow == null:
		push_error("save_current_world: save_flow is null")
		return
	if _save_serializer == null:
		push_error("save_current_world: save_serializer is null")
		return

	var entities_payload: Array = []
	if _main.world_root != null and is_instance_valid(_main.world_root):
		entities_payload = serialize_entities()

	var minimap_payload: Dictionary = {}
	if _main.minimap != null:
		minimap_payload = _save_serializer.serialize_minimap(_main.minimap)

	var selected_skills_payload: Array = []
	if typeof(SkillState) != TYPE_NIL:
		selected_skills_payload = SkillState.selected_skills

	var payload: Dictionary = _save_flow.build_save_payload(
		_main.world_index,
		_save_serializer.serialize_tilemap(_main.dungeon_floor),
		_save_serializer.serialize_tilemap(_main.dungeon_top),
		entities_payload,
		minimap_payload,
		selected_skills_payload
	)

	if not _save_flow.write_payload(payload):
		return

	print("Saved world tilemaps + entities to: ", _save_flow.SAVE_PATH)


func _deserialize_tilemap_for_save_flow(data: Dictionary) -> TileMapLayer:
	if _save_serializer == null:
		return null
	return _save_serializer.deserialize_tilemap(data)


func _deserialize_minimap_for_save_flow(data: Dictionary) -> Node:
	if _save_serializer == null:
		return null
	return _save_serializer.deserialize_minimap(data)


func load_world_from_file(idx: int) -> Dictionary:
	if _save_flow == null:
		push_error("load_world_from_file: save_flow is null")
		return {}

	var payload: Dictionary = _save_flow.read_payload()
	if payload.is_empty():
		return {}

	return _save_flow.build_loaded_world_result(
		payload,
		idx,
		Callable(self, "_deserialize_tilemap_for_save_flow"),
		Callable(self, "_deserialize_minimap_for_save_flow")
	)
