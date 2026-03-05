extends RefCounted


func _obj_has_property(obj: Object, prop: String) -> bool:
	if obj == null:
		return false
	if not obj.has_method("get_property_list"):
		return false
	for p in obj.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _apply_saved_position(target: Node, item: Dictionary, dungeon_floor: TileMapLayer) -> void:
	if target == null or dungeon_floor == null:
		return
	if typeof(item) != TYPE_DICTIONARY:
		return
	if not (target is Node2D):
		return

	var n2d := target as Node2D

	if item.has("grid_pos"):
		var grid_pos_raw = item.get("grid_pos")
		if typeof(grid_pos_raw) == TYPE_ARRAY and grid_pos_raw.size() >= 2:
			var grid_pos := Vector2i(int(grid_pos_raw[0]), int(grid_pos_raw[1]))
			n2d.global_position = dungeon_floor.to_global(dungeon_floor.map_to_local(grid_pos))
			if _obj_has_property(target, "grid_pos"):
				target.set("grid_pos", grid_pos)
			return

	if item.has("global_position"):
		var global_pos_raw = item.get("global_position")
		if typeof(global_pos_raw) == TYPE_ARRAY and global_pos_raw.size() >= 2:
			n2d.global_position = Vector2(float(global_pos_raw[0]), float(global_pos_raw[1]))


func connect_player_signals(
	owner: Object, player_node: Node, warn_missing_exit_signal: bool = false
) -> void:
	if owner == null or player_node == null:
		return

	var exit_cb := Callable(owner, "_on_player_exit_reached")
	if player_node.has_signal("exit_reached"):
		if not player_node.is_connected("exit_reached", exit_cb):
			player_node.connect("exit_reached", exit_cb)
	elif warn_missing_exit_signal:
		push_warning("player has no exit_reached signal")

	var moved_cb := Callable(owner, "_on_player_moved")
	if player_node.has_signal("player_moved"):
		if not player_node.is_connected("player_moved", moved_cb):
			player_node.connect("player_moved", moved_cb)


func update_player_visibility(player_node: Node) -> void:
	if player_node == null:
		return
	if player_node.has_method("update_visibility"):
		player_node.call("update_visibility")
		player_node.call_deferred("_reveal_on_spawn")


func serialize_entities(world_root: Node) -> Array:
	var out: Array = []
	if world_root == null:
		return out

	var nodes = world_root.get_children()
	for c in nodes:
		if c == null or not is_instance_valid(c):
			continue

		var t: String = ""
		if c.is_in_group("player") or str(c.name) == "Player":
			t = "player"
		elif c.is_in_group("enemy"):
			t = "enemy"
		elif c.is_in_group("merchant_entity"):
			t = "merchant"
		elif str(c.name).begins_with("Lootbox"):
			t = "lootbox"
		elif str(c.name).begins_with("Trap"):
			t = "trap"
		else:
			continue

		var item: Dictionary = {"type": t, "name": str(c.name)}

		if _obj_has_property(c, "grid_pos"):
			var gp = c.get("grid_pos")
			item["grid_pos"] = [int(gp.x), int(gp.y)]
		else:
			item["global_position"] = [float(c.global_position.x), float(c.global_position.y)]

		if t == "enemy":
			if _obj_has_property(c, "sprite_type"):
				item["sprite_type"] = str(c.get("sprite_type"))
			if _obj_has_property(c, "types"):
				item["behaviour"] = c.get("types")
			if _obj_has_property(c, "abilities_this_has"):
				item["skills"] = c.get("abilities_this_has")
			if _obj_has_property(c, "stats"):
				item["stats"] = c.get("stats")
		elif t == "merchant":
			if _obj_has_property(c, "merchant_id"):
				item["merchant_id"] = str(c.get("merchant_id"))
			if _obj_has_property(c, "merchant_room"):
				item["merchant_room"] = str(c.get("merchant_room"))
		elif t == "lootbox":
			if _obj_has_property(c, "lootbox_id"):
				item["lootbox_id"] = str(c.get("lootbox_id"))
		elif t == "trap":
			if _obj_has_property(c, "world_index"):
				item["world_index"] = int(c.get("world_index"))
		elif t == "player":
			if _obj_has_property(c, "hp"):
				item["hp"] = int(c.get("hp"))
			if _obj_has_property(c, "level"):
				item["level"] = int(c.get("level"))
			if _obj_has_property(c, "dynamic_fog"):
				item["dynamic_fog"] = bool(c.get("dynamic_fog"))
			if _obj_has_property(c, "fog_tile_id"):
				item["fog_tile_id"] = int(c.get("fog_tile_id"))
			item["inventory"] = PlayerInventory.inventory
			item["coins"] = int(PlayerInventory.coins)

		out.append(item)

	return out


func deserialize_entities(
	list_data: Array,
	container: Node,
	dungeon_floor: TileMapLayer,
	dungeon_top: TileMapLayer,
	fog_war_layer: Node,
	minimap: Node,
	scenes: Dictionary,
	defaults: Dictionary,
	owner: Object
) -> Node:
	if list_data == null or typeof(list_data) != TYPE_ARRAY:
		return null
	if container == null:
		push_error("EntityPersistenceFlow.deserialize_entities: container is null")
		return null

	var enemy_scene = scenes.get("enemy", null)
	var merchant_scene = scenes.get("merchant", null)
	var lootbox_scene = scenes.get("lootbox", null)
	var trap_scene = scenes.get("trap", null)
	var player_scene = scenes.get("player", null)

	var fog_dynamic: bool = bool(defaults.get("fog_dynamic", true))
	var fog_tile_id: int = int(defaults.get("fog_tile_id", 0))

	var loaded_player: Node = null

	for item in list_data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var t = str(item.get("type", ""))

		if t == "enemy":
			if enemy_scene == null:
				continue
			var e = enemy_scene.instantiate()
			if _obj_has_property(e, "sprite_type"):
				e.set("sprite_type", str(item.get("sprite_type", "")))
			if _obj_has_property(e, "types"):
				e.set("types", item.get("behaviour", []))
			if _obj_has_property(e, "abilities_this_has"):
				e.set("abilities_this_has", item.get("skills", []))

			var stats = item.get("stats", {})
			var hp = int(stats.get("hp", 1))
			var strv = int(stats.get("str", 1))
			var defv = int(stats.get("def", 1))
			e.setup(dungeon_floor, dungeon_top, hp, strv, defv, stats)
			e.add_to_group("enemy")
			e.add_to_group("vision_objects")
			container.add_child(e)
			_apply_saved_position(e, item, dungeon_floor)

		elif t == "merchant":
			if merchant_scene == null:
				continue
			var m = merchant_scene.instantiate()
			if _obj_has_property(m, "merchant_id") and item.has("merchant_id"):
				m.set("merchant_id", str(item.get("merchant_id")))
			if _obj_has_property(m, "merchant_room") and item.has("merchant_room"):
				m.set("merchant_room", str(item.get("merchant_room")))
			container.add_child(m)
			m.add_to_group("vision_objects")
			_apply_saved_position(m, item, dungeon_floor)

		elif t == "lootbox":
			if lootbox_scene == null:
				continue
			var l = lootbox_scene.instantiate()
			if _obj_has_property(l, "lootbox_id") and item.has("lootbox_id"):
				l.set("lootbox_id", str(item.get("lootbox_id")))
			l.add_to_group("vision_objects")
			container.add_child(l)
			_apply_saved_position(l, item, dungeon_floor)

		elif t == "trap":
			if trap_scene == null:
				continue
			var tr = trap_scene.instantiate()
			if _obj_has_property(tr, "world_index") and item.has("world_index"):
				tr.set("world_index", int(item.get("world_index")))
			container.add_child(tr)
			tr.add_to_group("vision_objects")
			_apply_saved_position(tr, item, dungeon_floor)

		elif t == "player":
			if player_scene == null:
				continue
			var p = player_scene.instantiate()
			p.name = "Player"
			if _obj_has_property(p, "dynamic_fog"):
				p.set("dynamic_fog", bool(item.get("dynamic_fog", fog_dynamic)))
			if _obj_has_property(p, "fog_tile_id"):
				p.set("fog_tile_id", int(item.get("fog_tile_id", fog_tile_id)))
			var php = int(item.get("hp", 10))
			p.setup(dungeon_floor, dungeon_top, php, 3, 0, {})
			p.fog_layer = fog_war_layer
			container.add_child(p)
			loaded_player = p
			loaded_player.set_minimap(minimap)
			_apply_saved_position(loaded_player, item, dungeon_floor)
			connect_player_signals(owner, loaded_player)
			update_player_visibility(loaded_player)
			if owner != null and owner.has_method("emit_signal"):
				owner.emit_signal("player_spawned", loaded_player)

			var did_restore_inventory_state := false
			if item.has("inventory"):
				var inv = item.get("inventory")
				var fixed_inv: Dictionary = {}
				for k in inv.keys():
					fixed_inv[int(k)] = inv[k]
				PlayerInventory.inventory = fixed_inv
				did_restore_inventory_state = true
			if item.has("coins"):
				PlayerInventory.coins = int(item.get("coins", PlayerInventory.coins))
				did_restore_inventory_state = true
			if did_restore_inventory_state:
				PlayerInventory._emit_changed()

	return loaded_player
