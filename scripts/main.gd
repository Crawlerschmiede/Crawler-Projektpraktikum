extends Node2D

# gdlint: disable=max-file-lines

signal player_spawned
const ENEMY_SCENE = preload("res://scenes/entity/enemy.tscn")
const BATTLE_SCENE = preload("res://scenes/UI/battle.tscn")
const PLAYER_SCENE = preload("res://scenes/entity/player-character-scene.tscn")
const LOOTBOX = preload("res://scenes/Interactables/Lootbox.tscn")
const TRAP = preload("res://scenes/Interactables/Trap.tscn")
const MERCHANT = preload("res://scenes/entity/merchant.tscn")
const LOADING_SCENE = preload("res://scenes/UI/loading_screen.tscn")
const SKILLTREE_SELECT_SCENE = preload("res://scenes/UI/skilltree-select-menu.tscn")
const SKILLTREE_UPGRADING_SCENE = preload("res://scenes/UI/skilltree-upgrading.tscn")
const UI_MODAL_CONTROLLER = preload("res://scripts/UI/ui_modal_controller.gd")
const START_SCENE = "res://scenes/UI/start-menu.tscn"
const DEATH_SCENE = "res://scenes/UI/death-screen.tscn"
const DEATH_SCENE_PACKED = preload("res://scenes/UI/death-screen.tscn")
const SEWER_TILESET = "res://scenes/rooms/Rooms/roomtiles_2world.tres"
const TUTORIAL_ROOM = "res://scenes/rooms/Tutorial Rooms/tutorial_room.tscn"
@export var menu_scene = preload("res://scenes/UI/popup-menu.tscn")
@export var fog_tile_id: int = 0  # set this in the inspector to the fog-tile id in your tileset
@export var fog_dynamic: bool = true  # if true, areas that are no longer visible get fogged again

# --- World state ---
var world_index: int = -1
var generators: Array[Node2D] = []

var world_root: Node2D = null
var dungeon_floor: TileMapLayer = null
var dungeon_top: TileMapLayer = null

var saved_maps: Dictionary = {}

var player: PlayerCharacter = null
var menu_instance: CanvasLayer = null
var battle: CanvasLayer = null

var loading_screen: CanvasLayer = null

var switching_world = false

var boss_win: bool = false

@onready var backgroundtile = $TileMapLayer

@onready var minimap: TileMapLayer

@onready var generator1: Node2D = $World1
@onready var generator2: Node2D = $World2
@onready var generator3: Node2D = $World3

@onready var fog_war_layer = $FogWar


func _ready() -> void:
	UI_MODAL_CONTROLLER.set_debug_enabled(OS.is_debug_build())
	generators = [generator1, generator2, generator3]

	# If user requested loading from save, try to pre-load save data
	# BEFORE showing skill selection so previously selected skills are restored
	if SaveState.load_from_save:
		var early_loaded = load_world_from_file(0)
		if typeof(early_loaded) == TYPE_DICTIONARY and not early_loaded.is_empty():
			# restore selected skills into SkillState autoload if available
			if typeof(SkillState) != TYPE_NIL and early_loaded.has("selected_skills"):
				SkillState.selected_skills = early_loaded.get("selected_skills", [])
			# keep the loaded maps for later use in _load_world
			saved_maps = early_loaded
			world_index = int(early_loaded.get("world_index", 0))

	await _show_skilltree_select_menu()
	await _show_skilltree_upgrading_menu()

	# Tutorial prüfen (JSON: res://data/tutorialData.json)
	if _has_completed_tutorial() == false:
		await _load_tutorial_world()
		return
	if SaveState.load_from_save and (saved_maps == {} or not (typeof(saved_maps) == TYPE_DICTIONARY and saved_maps.has("floor"))):
		# No early-loaded save present -> load now
		var loaded = load_world_from_file(0)
		if loaded == {}:
			push_error(
				"_ready: requested load_from_save but load failed; falling back to new world"
			)
			world_index = 0
		else:
			saved_maps = loaded
			world_index = int(loaded.get("world_index", 0))
	elif not SaveState.load_from_save and (saved_maps == {} or not typeof(saved_maps) == TYPE_DICTIONARY):
		world_index = 0

	await _load_world(world_index)


func _show_skilltree_select_menu() -> void:
	var skilltree_select = SKILLTREE_SELECT_SCENE.instantiate()
	if skilltree_select == null:
		push_warning(
			"Failed to instantiate skilltree select menu; continuing startup without selection"
		)
		return

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "SkilltreeSelectOverlay"
	ui_layer.layer = 100
	add_child(ui_layer)
	ui_layer.add_child(skilltree_select)

	if skilltree_select is Control:
		skilltree_select.set_anchors_preset(Control.PRESET_FULL_RECT)
		skilltree_select.offset_left = 0
		skilltree_select.offset_top = 0
		skilltree_select.offset_right = 0
		skilltree_select.offset_bottom = 0

	if skilltree_select.has_signal("selection_confirmed"):
		await skilltree_select.selection_confirmed

	if is_instance_valid(ui_layer):
		ui_layer.queue_free()


func _show_skilltree_upgrading_menu() -> void:
	var skilltree_upgrading = SKILLTREE_UPGRADING_SCENE.instantiate()
	if skilltree_upgrading == null:
		push_warning("Failed to instantiate skilltree upgrading menu; continuing startup")
		return

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "SkilltreeUpgradingOverlay"
	ui_layer.layer = 100
	add_child(ui_layer)
	ui_layer.add_child(skilltree_upgrading)

	if skilltree_upgrading is Control:
		skilltree_upgrading.set_anchors_preset(Control.PRESET_FULL_RECT)
		skilltree_upgrading.offset_left = 0
		skilltree_upgrading.offset_top = 0
		skilltree_upgrading.offset_right = 0
		skilltree_upgrading.offset_bottom = 0

	if skilltree_upgrading.has_signal("closed"):
		await skilltree_upgrading.closed

	if is_instance_valid(ui_layer):
		ui_layer.queue_free()


func _set_tree_paused(value: bool) -> void:
	var scene_tree = get_tree()
	if scene_tree != null:
		scene_tree.paused = value
	else:
		push_warning("_set_tree_paused: SceneTree is null; ignored")


func _load_tutorial_world() -> void:
	_set_tree_paused(true)
	await _show_loading()

	_clear_world()

	# Reset boss flag when loading a world so previous boss state doesn't leak
	boss_win = false

	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)

	# Versuche zuerst, die Tutorial-Szene als Generator zu behandeln
	var TutorialPacked = preload(TUTORIAL_ROOM)
	var tutorial_inst = TutorialPacked.instantiate()

	if tutorial_inst != null and tutorial_inst.has_method("get_random_tilemap"):
		# Generator-API vorhanden -> wie bei _load_world verwenden
		var maps: Dictionary = await tutorial_inst.get_random_tilemap()

		if maps.is_empty():
			push_warning("Tutorial generator returned empty maps, falling back to scene extraction")
		else:
			dungeon_floor = maps.get("floor", null)
			dungeon_top = maps.get("top", null)
			minimap = maps.get("minimap", null)

			# attach maps to world_root if not parented
			if dungeon_floor != null and dungeon_floor.get_parent() == null:
				world_root.add_child(dungeon_floor)
			if dungeon_top != null and dungeon_top.get_parent() == null:
				world_root.add_child(dungeon_top)

			if fog_war_layer != null and dungeon_floor != null:
				init_fog_layer()

			if dungeon_floor != null:
				dungeon_floor.visibility_layer = 1

			spawn_player()
			spawn_enemies(false)
			spawn_lootbox()
			spawn_traps()
			spawn_enemies(true)

			var merchants = find_merchants()
			for i in merchants:
				spawn_merchant_entity(i)

			_hide_loading()
			get_tree().paused = false
			if is_instance_valid(tutorial_inst):
				tutorial_inst.queue_free()
			return

	# Fallback: Tutorial-Szene wie bisher parsen (TileMapLayer / Area2D etc.)
	var tutorial_scene = tutorial_inst as Node2D
	if tutorial_scene == null:
		push_error("Failed to load tutorial scene!")
		_hide_loading()
		_set_tree_paused(false)
		return

	# Extrahiere Tilemaps aus der Tutorial Room
	var tilemaps = tutorial_scene.find_children("*", "TileMapLayer")

	if tilemaps.is_empty():
		push_error("Tutorial scene has no TileMapLayer!")
		_hide_loading()
		_set_tree_paused(false)
		return

	# Nutze die erste Tilemap als floor
	dungeon_floor = tilemaps[0] as TileMapLayer

	# Falls es mehrere gibt, nimm die mit "floor" im Namen oder die zweite als top
	if tilemaps.size() > 1:
		for tm in tilemaps:
			if tm.name.to_lower().contains("tile"):
				dungeon_floor = tm as TileMapLayer
			elif tm.name.to_lower().contains("top"):
				dungeon_top = tm as TileMapLayer

		# Falls kein "top" gefunden, nutze die zweite Tilemap
		if dungeon_top == null and tilemaps.size() > 1:
			dungeon_top = tilemaps[1] as TileMapLayer
	else:
		# Wenn nur eine Tilemap, nutze sie auch als top
		dungeon_top = dungeon_floor

	# Verschiebe alle TileMapLayers zum world_root
	for tm in tilemaps:
		if tm.get_parent() != null:
			tm.get_parent().remove_child(tm)
		world_root.add_child(tm)
		tm.position = Vector2.ZERO

	# Extrahiere und verschiebe alle Area2D-Nodes mit ihren Kindern
	var area2ds = tutorial_scene.find_children("*", "Area2D")
	for area in area2ds:
		if area.get_parent() != null:
			area.get_parent().remove_child(area)
		world_root.add_child(area)
		area.position = Vector2.ZERO

	# Extrahiere und verschiebe auch alle StaticBody2D und andere Physics-Bodies für Obstacles
	var physics_bodies = tutorial_scene.find_children("*", "PhysicsBody2D")
	for body in physics_bodies:
		if body.get_parent() != null:
			body.get_parent().remove_child(body)
		world_root.add_child(body)
		body.position = Vector2.ZERO

	# Die restliche Tutorial-Szene kann gelöscht werden
	tutorial_scene.queue_free()

	# Initialize fog layer
	if fog_war_layer != null and dungeon_floor != null:
		# Reparent fog layer into world_root so z_index ordering works across the same parent
		if fog_war_layer.get_parent() != world_root:
			var old_parent = fog_war_layer.get_parent()
			if old_parent != null:
				old_parent.remove_child(fog_war_layer)
			world_root.add_child(fog_war_layer)
			# align position after reparenting
			fog_war_layer.position = dungeon_floor.position
		# Set fog z to be above dungeon_top (or dungeon_floor)
		var base_z = 0
		if dungeon_top != null:
			base_z = dungeon_top.z_index
		elif dungeon_floor != null:
			base_z = dungeon_floor.z_index
		fog_war_layer.z_index = base_z + 10
		await init_fog_layer()

	dungeon_floor.visibility_layer = 1
	# Spawne alle Entities wie in normalen Welten
	spawn_player()
	spawn_enemies(false)
	spawn_lootbox()
	spawn_traps()
	await get_tree().process_frame
	await get_tree().process_frame
	_on_player_moved()

	var merchants = find_merchants()
	for i in merchants:
		spawn_merchant_entity(i)

	_hide_loading()
	_set_tree_paused(false)


func _load_world(idx: int) -> void:
	_set_tree_paused(true)
	await _show_loading()

	_clear_world()

	if idx < 0 or idx >= generators.size():
		push_error("No more worlds left!")
		_hide_loading()
		_set_tree_paused(false)
		return

	var gen = generators[idx]

	# Loading screen mit Generator verbinden
	if loading_screen != null and is_instance_valid(loading_screen) and gen != null:
		if loading_screen.has_method("bind_to_generator"):
			loading_screen.call("bind_to_generator", gen)

	# -------------------------------------------------
	# WorldRoot + Entity Container erstellen
	# -------------------------------------------------
	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)

	var entity_container = Node2D.new()
	entity_container.name = "Entities"
	world_root.add_child(entity_container)
	entity_container.z_index = 3

	# -------------------------------------------------
	# Maps vom Generator oder aus Save laden
	# -------------------------------------------------+
	if saved_maps and typeof(saved_maps) == TYPE_DICTIONARY and saved_maps.has("floor"):
		dungeon_floor = saved_maps.get("floor", null)
		dungeon_top = saved_maps.get("top", null)
		minimap = saved_maps.get("minimap", null)
		if minimap != null:
			if minimap.get_parent() != world_root:
				world_root.add_child(minimap)

			minimap.position = dungeon_floor.position
			minimap.z_index = -50
			minimap.visibility_layer = 1 << 1

			# Alle RoomLayer erstmal unsichtbar machen
			for child in minimap.get_children():
				if child is TileMapLayer:
					var layer := child as TileMapLayer

					# Background darf sichtbar bleiben
					if layer.name == "MinimapBackground":
						layer.visible = true
						continue

					# Nur echte RoomLayer unsichtbar starten
					if layer.has_meta("tile_origin") or layer.has_meta("room_rect"):
						layer.visible = false
	elif not SaveState.load_from_save:
		var maps: Dictionary = await gen.get_random_tilemap()

		if maps.is_empty():
			push_error("Generator returned empty dictionary!")
			_hide_loading()
			_set_tree_paused(false)
			return
		dungeon_floor = maps.get("floor", null)
		dungeon_top = maps.get("top", null)
		minimap = maps.get("minimap", null)
	else:
		push_error(
			"_load_world: requested load_from_save but no saved_maps available; falling back to generator"
		)
		var maps_fallback: Dictionary = await gen.get_random_tilemap()
		if maps_fallback.is_empty():
			push_error("Generator returned empty dictionary!")
			_hide_loading()
			_set_tree_paused(false)
			return
		dungeon_floor = maps_fallback.get("floor", null)
		dungeon_top = maps_fallback.get("top", null)
		minimap = maps_fallback.get("minimap", null)

	dungeon_floor.owner = world_root
	dungeon_top.owner = world_root

	if dungeon_floor == null:
		push_error("Generator returned null floor tilemap!")
		_hide_loading()
		_set_tree_paused(false)
		return

	# -------------------------------------------------
	# Tileset Override für Welt 2
	# -------------------------------------------------
	if idx == 1:
		var sewer_tileset = load(SEWER_TILESET) as TileSet
		if sewer_tileset != null:
			dungeon_floor.tile_set = sewer_tileset
			if dungeon_top != null:
				dungeon_top.tile_set = sewer_tileset

	# -------------------------------------------------
	# Tilemaps hinzufügen + Layering
	# -------------------------------------------------
	if dungeon_floor.get_parent() == null:
		world_root.add_child(dungeon_floor)
	dungeon_floor.z_index = 0

	if dungeon_top != null:
		if dungeon_top.get_parent() == null:
			world_root.add_child(dungeon_top)
		dungeon_top.z_index = 1  # über Entities, unter Fog

	# Fog über alles (sicherstellen, dass Fog über dungeon_top liegt)
	if fog_war_layer != null:
		# Reparent fog layer into world_root so its z_index compares with dungeon_top (same parent)
		if fog_war_layer.get_parent() != world_root:
			var old_parent = fog_war_layer.get_parent()
			if old_parent != null:
				old_parent.remove_child(fog_war_layer)
			world_root.add_child(fog_war_layer)
			fog_war_layer.position = dungeon_floor.position
		# compute base z from dungeon_top if available
		var base_z = 0
		if dungeon_top != null:
			base_z = dungeon_top.z_index
		elif dungeon_floor != null:
			base_z = dungeon_floor.z_index
		fog_war_layer.z_index = base_z + 10
		await init_fog_layer()

	# -------------------------------------------------
	# Minimap Background
	# -------------------------------------------------
	if minimap != null and backgroundtile != null:
		var bg = backgroundtile.duplicate() as TileMapLayer
		bg.set_meta("is_background", true)
		bg.visible = true
		bg.name = "MinimapBackground"
		bg.visibility_layer = 1 << 1
		bg.z_index = -100
		minimap.add_child(bg)
		minimap.move_child(bg, -1)

	dungeon_floor.visibility_layer = 1
	# -------------------------------------------------
	# Spawns / restore from save
	# -------------------------------------------------
	if saved_maps != null and typeof(saved_maps) == TYPE_DICTIONARY and saved_maps.has("entities"):
		_deserialize_entities(saved_maps.get("entities", []))
		# clear saved_maps so subsequent loads are fresh
		saved_maps = {}
	else:
		spawn_player()
		spawn_enemies(false)
		spawn_lootbox()
		spawn_traps()
		spawn_enemies(true)

		var merchants = find_merchants()
		for i in merchants:
			spawn_merchant_entity(i)

	# -------------------------------------------------
	# Fertig
	# -------------------------------------------------
	_hide_loading()
	SaveState.load_from_save = false
	_set_tree_paused(false)


func spawn_merchant_entity(cords: Vector2) -> void:
	var e = MERCHANT.instantiate()
	e.add_to_group("merchant_entity")

	e.global_position = cords

	# assign a stable merchant id based on spawn coordinates and world index
	# so the in-memory registry can distinguish merchants reliably
	if e.has_method("set"):
		var id = "merchant_%d_%d_world%d" % [int(cords.x), int(cords.y), int(world_index)]
		# set merchant_id via set() (safe even if exported property is empty)
		e.set("merchant_id", id)
		# set merchant_room key as requested
		e.set("merchant_room", "merchant_room")

	if world_root != null:
		world_root.add_child(e)
	else:
		add_child(e)


func _show_loading() -> void:
	loading_screen = LOADING_SCENE.instantiate() as CanvasLayer
	add_child(loading_screen)

	if loading_screen != null:
		loading_screen.layer = 100
	else:
		push_error("_show_loading: loading_screen instance is null")
	loading_screen.visible = true
	loading_screen.process_mode = Node.PROCESS_MODE_ALWAYS

	move_child(loading_screen, get_child_count() - 1)

	await get_tree().process_frame
	await get_tree().process_frame


func _show_start() -> void:
	var start_screen = preload(START_SCENE).instantiate() as CanvasLayer
	add_child(start_screen)

	start_screen.layer = 1000

	start_screen.visible = true
	start_screen.process_mode = Node.PROCESS_MODE_ALWAYS

	move_child(start_screen, get_child_count() - 1)

	# Connect Start New signal so clicking the button starts a new game (loads a new map)
	if start_screen.has_signal("start_new_pressed"):
		start_screen.start_new_pressed.connect(_on_start_new_pressed)

	await get_tree().process_frame
	await get_tree().process_frame


func _on_start_new_pressed() -> void:
	# Close start menu if present
	var start_node = get_node_or_null("StartMenu")
	if start_node != null and is_instance_valid(start_node):
		start_node.call_deferred("queue_free")

	# Reset to first world and load
	world_index = 0
	await _load_world(world_index)


func _hide_loading() -> void:
	if loading_screen != null and is_instance_valid(loading_screen):
		loading_screen.visible = false


func spawn_traps() -> void:
	if dungeon_floor == null or world_root == null:
		return

	var tile_set = dungeon_floor.tile_set
	if tile_set == null:
		return

	if not _has_custom_data_layer(tile_set, "trap_spawnable"):
		push_warning("TileSet has no custom data layer 'trap_spawnable'. Skipping trap spawns.")
		return

	# alte Lootboxen entfernen
	for c in world_root.get_children():
		if c != null and c.name.begins_with("Trap"):
			c.queue_free()

	# alle möglichen Lootbox-Spawns sammeln
	var candidates: Array[Vector2i] = []
	for cell in dungeon_floor.get_used_cells():
		var td = dungeon_floor.get_cell_tile_data(cell)
		if td == null:
			continue

		# Tileset Custom Data Bool
		if td.get_custom_data("trap_spawnable") == true:
			candidates.append(cell)

	if candidates.is_empty():
		return

	# maximal 20 Lootboxen
	GlobalRNG.shuffle_array(candidates)
	var amount = min(20, candidates.size())

	for i in range(amount):
		var spawn_cell = candidates[i]
		var world_pos = dungeon_floor.to_global(dungeon_floor.map_to_local(spawn_cell))

		var loot = TRAP.instantiate() as Node2D
		loot.name = "Trap_%s" % i
		# assign current world index so the trap knows which world it belongs to
		if loot.has_method("set"):
			loot.set("world_index", world_index)
		world_root.add_child(loot)
		loot.global_position = world_pos


func spawn_lootbox() -> void:
	if dungeon_floor == null or world_root == null:
		return

	var tile_set = dungeon_floor.tile_set
	if tile_set == null:
		return

	if not _has_custom_data_layer(tile_set, "lootbox_spawnable"):
		push_warning(
			"TileSet has no custom data layer 'lootbox_spawnable'. Skipping lootbox spawns."
		)
		return

	# alte Lootboxen entfernen
	for c in world_root.get_children():
		if c != null and c.name.begins_with("Lootbox"):
			c.queue_free()

	# alle möglichen Lootbox-Spawns sammeln
	var candidates: Array[Vector2i] = []
	for cell in dungeon_floor.get_used_cells():
		var td = dungeon_floor.get_cell_tile_data(cell)
		if td == null:
			continue

		# Tileset Custom Data Bool
		if td.get_custom_data("lootbox_spawnable") == true:
			candidates.append(cell)

	if candidates.is_empty():
		return

	# maximal 20 Lootboxen
	GlobalRNG.shuffle_array(candidates)
	var amount = min(20, candidates.size())

	for i in range(amount):
		var spawn_cell = candidates[i]
		var world_pos = dungeon_floor.to_global(dungeon_floor.map_to_local(spawn_cell))

		var loot = LOOTBOX.instantiate() as Node2D
		loot.name = "Lootbox_%s" % i
		if loot.has_method("set"):
			loot.set("lootbox_id", "lootbox_%s" % i)
		world_root.add_child(loot)
		loot.global_position = world_pos


func _disable_lootbox_blocking(loot: Node) -> void:
	if loot == null:
		return

	# Falls Lootbox StaticBody2D / CharacterBody2D etc. hat: deaktivieren
	var bodies = loot.find_children("*", "PhysicsBody2D", true, false)
	for b in bodies:
		if b != null:
			b.set_deferred("collision_layer", 0)
			b.set_deferred("collision_mask", 0)

	# Falls Lootbox Area2D hat: darf triggern, aber nicht blocken
	var areas = loot.find_children("*", "Area2D", true, false)
	for a in areas:
		if a != null:
			# Area darf nur "triggern", aber nix blocken
			a.set_deferred("collision_layer", 0)
			a.set_deferred("collision_mask", 0)

	# Alle CollisionShapes deaktivieren (sicherster Weg)
	var shapes = loot.find_children("*", "CollisionShape2D", true, false)
	for s in shapes:
		if s != null:
			s.set_deferred("disabled", true)


func _has_custom_data_layer(tile_set: TileSet, layer_name: String) -> bool:
	if tile_set == null:
		return false

	var layer_count = tile_set.get_custom_data_layers_count()
	for i in range(layer_count):
		if tile_set.get_custom_data_layer_name(i) == layer_name:
			return true

	return false


func init_fog_layer() -> void:
	# Fill the FogWar TileMapLayer with a fog tile so Player.update_visibility can erase cells.
	if fog_war_layer == null or dungeon_floor == null:
		return

	# align tileset + transform so coordinates match
	fog_war_layer.clear()
	fog_war_layer.tile_set = dungeon_floor.tile_set
	# align position/visibility/z so it overlays the floor
	fog_war_layer.position = dungeon_floor.position
	fog_war_layer.visibility_layer = dungeon_floor.visibility_layer
	# Ensure fog layer is above the dungeon_top layer (if present) or above the floor otherwise
	var base_z = 0
	if dungeon_top != null:
		base_z = dungeon_top.z_index
	elif dungeon_floor != null:
		base_z = dungeon_floor.z_index
	fog_war_layer.z_index = base_z + 10

	# Debug info: print parent and z indices so we can observe ordering at runtime
	var counter = 0
	var used_rect = dungeon_floor.get_used_rect()
	var yield_every = 300
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell = Vector2i(x, y)
			# skip empty cells
			if dungeon_floor.get_cell_source_id(cell) == -1:
				continue
			fog_war_layer.set_cell(cell, 2, Vector2(2, 4), 0)
			counter += 1
			if counter % yield_every == 0:
				await get_tree().process_frame


func _clear_world() -> void:
	# battle weg
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
		battle = null

	# menu weg (optional)
	if menu_instance != null and is_instance_valid(menu_instance):
		menu_instance.queue_free()
		menu_instance = null

	# player weg
	if player != null and is_instance_valid(player):
		player.queue_free()
		player = null

	if world_root != null and is_instance_valid(world_root):
		# Preserve fog_war_layer if it was reparented into world_root so it is not freed
		if fog_war_layer != null and is_instance_valid(fog_war_layer):
			if fog_war_layer.get_parent() == world_root:
				world_root.remove_child(fog_war_layer)
				add_child(fog_war_layer)

		world_root.queue_free()
		world_root = null

	dungeon_floor = null
	dungeon_top = null

	# Reset entity spawn reservations so next world can reuse positions
	if EntityAutoload != null and EntityAutoload.has_method("reset"):
		EntityAutoload.reset()


func _on_player_exit_reached() -> void:
	if switching_world:
		return

	# Prevent progressing if a boss is still alive in the world
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != null and is_instance_valid(e):
			# enemies spawned by spawn_enemy have a `boss` property
			if bool(e.boss) and e.hp > 0:
				push_warning("You must defeat the boss before advancing!")
				return

	switching_world = true

	# Prüfen: Sind wir im Tutorial? (Tutorial hat keine Minimap)
	if world_index == -1:
		_set_tutorial_completed()

	# Normale Welten
	world_index += 1
	await _load_world(world_index)

	switching_world = false


# ---------------------------------------
# UI / MENU
# ---------------------------------------
func _process(_delta) -> void:
	if Input.is_action_just_pressed("ui_menu"):
		if _is_binds_overlay_active():
			return
		toggle_menu()


func _is_binds_overlay_active() -> bool:
	var root = get_tree().root
	if root == null:
		return false

	var overlay = root.find_child("BindsAndMenusOverlay", true, false)
	return overlay != null


func update_minimap_player_marker() -> void:
	if minimap == null or dungeon_floor == null or player == null:
		return

	var marker = minimap.get_node_or_null("PlayerMarker")
	if marker == null:
		push_warning("Minimap has no PlayerMarker node")
		return

	# 1) Player global -> floor local -> map cell
	var world_cell: Vector2i = dungeon_floor.local_to_map(
		dungeon_floor.to_local(player.global_position)
	)

	# 2) world_cell -> minimap local position
	# minimap.map_to_local gibt dir Pixelposition im Minimap-Tilegrid
	var mini_pos: Vector2 = minimap.map_to_local(world_cell)

	# 3) Marker setzen (lokal zur minimap)
	marker.position = mini_pos


func toggle_menu():
	if menu_instance == null:
		menu_instance = menu_scene.instantiate()
		add_child(menu_instance)

		UI_MODAL_CONTROLLER.acquire(self, true, true)

		if menu_instance.has_signal("menu_closed"):
			menu_instance.menu_closed.connect(on_menu_closed)

		# Connect save_requested directly to main if the popup exposes it
		if menu_instance.has_signal("save_requested"):
			var cb = Callable(self, "save_current_world")
			if not menu_instance.is_connected("save_requested", cb):
				menu_instance.connect("save_requested", cb)
			# already connected -> ignore
		else:
			push_error("toggle_menu: popup menu missing 'save_requested' signal; save unavailable")
	else:
		on_menu_closed()


func on_menu_closed():
	if menu_instance != null and is_instance_valid(menu_instance):
		menu_instance.queue_free()
		menu_instance = null
	UI_MODAL_CONTROLLER.release(self, true, true)


func _serialize_tilemap(tm: TileMapLayer) -> Dictionary:
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

	# meta
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

	# cells
	out["cells"] = []
	for cell in tm.get_used_cells():
		var atlas: Vector2i = tm.get_cell_atlas_coords(cell)
		var item = {
			"x": int(cell.x),
			"y": int(cell.y),
			"source_id": int(tm.get_cell_source_id(cell)),
			"atlas": [int(atlas.x), int(atlas.y)],  # <- WICHTIG: immer als Array speichern
			"alt": int(tm.get_cell_alternative_tile(cell)),
		}
		out["cells"].append(item)

	return out


func _deserialize_tilemap(data: Dictionary) -> TileMapLayer:
	if data == null or typeof(data) != TYPE_DICTIONARY or data.is_empty():
		return null

	var tm = TileMapLayer.new()
	tm.clear()

	# restore tileset
	var ts_path = str(data.get("tile_set", ""))
	if ts_path != "":
		var ts = load(ts_path)
		if ts != null and ts is TileSet:
			tm.tile_set = ts

	# restore basic props
	tm.name = str(data.get("name", "TileMapLayer"))
	var pos_arr = data.get("position", [0.0, 0.0])
	if typeof(pos_arr) == TYPE_ARRAY and pos_arr.size() >= 2:
		tm.position = Vector2(float(pos_arr[0]), float(pos_arr[1]))

	tm.z_index = int(data.get("z_index", 0))
	tm.visibility_layer = int(data.get("visibility_layer", 1))

	# restore meta
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

	# restore cells
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


func _serialize_minimap(minimap_node: Node) -> Dictionary:
	if minimap_node == null:
		return {}

	# If it's a TileMapLayer, serialize directly
	if minimap_node is TileMapLayer:
		return {"type": "single", "tilemap": _serialize_tilemap(minimap_node)}

	# Otherwise serialize child TileMapLayer nodes
	var out: Dictionary = {"type": "group", "children": []}
	for child in minimap_node.get_children():
		if child is TileMapLayer:
			out["children"].append(_serialize_tilemap(child))

	return out


func _deserialize_minimap(data: Dictionary) -> Node:
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return null
	if str(data.get("type", "")) == "single":
		var tm_data = data.get("tilemap", {})
		return _deserialize_tilemap(tm_data)

	# group
	var root = Node2D.new()
	root.name = "Minimap"
	var children = data.get("children", [])
	for cd in children:
		var tm = _deserialize_tilemap(cd)
		if tm != null:
			root.add_child(tm)

	return root


func _serialize_entities() -> Array:
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

		# prefer grid_pos if available
		if _obj_has_property(c, "grid_pos"):
			var gp = c.get("grid_pos")
			item["grid_pos"] = [int(gp.x), int(gp.y)]
		else:
			item["global_position"] = [float(c.global_position.x), float(c.global_position.y)]

		# type-specific data
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

		out.append(item)

	return out


func _deserialize_entities(list_data: Array) -> void:
	if list_data == null or typeof(list_data) != TYPE_ARRAY:
		return

	if world_root == null:
		push_error("_deserialize_entities: world_root is null")
		return

	var container = world_root

	for item in list_data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var t = str(item.get("type", ""))

		if t == "enemy":
			var e = ENEMY_SCENE.instantiate()
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
			# position
			if item.has("grid_pos"):
				var gp = item.get("grid_pos")
				var gpi = Vector2i(int(gp[0]), int(gp[1]))
				e.global_position = dungeon_floor.to_global(dungeon_floor.map_to_local(gpi))
				e.grid_pos = gpi
			elif item.has("global_position"):
				var gp2 = item.get("global_position")
				e.global_position = Vector2(float(gp2[0]), float(gp2[1]))

		elif t == "merchant":
			var m = MERCHANT.instantiate()
			if _obj_has_property(m, "merchant_id") and item.has("merchant_id"):
				m.set("merchant_id", str(item.get("merchant_id")))
			if _obj_has_property(m, "merchant_room") and item.has("merchant_room"):
				m.set("merchant_room", str(item.get("merchant_room")))
			container.add_child(m)
			m.add_to_group("vision_objects")
			if item.has("grid_pos"):
				var gp3 = item.get("grid_pos")
				m.global_position = dungeon_floor.to_global(
					dungeon_floor.map_to_local(Vector2i(int(gp3[0]), int(gp3[1])))
				)
			elif item.has("global_position"):
				var gp4 = item.get("global_position")
				m.global_position = Vector2(float(gp4[0]), float(gp4[1]))

		elif t == "lootbox":
			var l = LOOTBOX.instantiate()
			if _obj_has_property(l, "lootbox_id") and item.has("lootbox_id"):
				l.set("lootbox_id", str(item.get("lootbox_id")))
			l.add_to_group("vision_objects")
			container.add_child(l)
			if item.has("grid_pos"):
				var gp5 = item.get("grid_pos")
				l.global_position = dungeon_floor.to_global(
					dungeon_floor.map_to_local(Vector2i(int(gp5[0]), int(gp5[1])))
				)
			elif item.has("global_position"):
				var gp6 = item.get("global_position")
				l.global_position = Vector2(float(gp6[0]), float(gp6[1]))

		elif t == "trap":
			var tr = TRAP.instantiate()
			if _obj_has_property(tr, "world_index") and item.has("world_index"):
				tr.set("world_index", int(item.get("world_index")))
			container.add_child(tr)
			tr.add_to_group("vision_objects")
			if item.has("grid_pos"):
				var gp7 = item.get("grid_pos")
				tr.global_position = dungeon_floor.to_global(
					dungeon_floor.map_to_local(Vector2i(int(gp7[0]), int(gp7[1])))
				)
			elif item.has("global_position"):
				var gp8 = item.get("global_position")
				tr.global_position = Vector2(float(gp8[0]), float(gp8[1]))

		elif t == "player":
			var p = PLAYER_SCENE.instantiate()
			p.name = "Player"
			if _obj_has_property(p, "dynamic_fog"):
				p.set("dynamic_fog", bool(item.get("dynamic_fog", fog_dynamic)))
			if _obj_has_property(p, "fog_tile_id"):
				p.set("fog_tile_id", int(item.get("fog_tile_id", fog_tile_id)))
			var php = int(item.get("hp", 10))
			p.setup(dungeon_floor, dungeon_top, php, 3, 0, {})
			p.fog_layer = fog_war_layer
			container.add_child(p)
			player = p
			player.set_minimap(minimap)
			if item.has("grid_pos"):
				var gp9 = item.get("grid_pos")
				player.grid_pos = Vector2i(int(gp9[0]), int(gp9[1]))
				player.global_position = dungeon_floor.to_global(
					dungeon_floor.map_to_local(player.grid_pos)
				)
			elif item.has("global_position"):
				var gp10 = item.get("global_position")
				player.global_position = Vector2(float(gp10[0]), float(gp10[1]))

			# connect signals
			if player.has_signal("exit_reached"):
				if not player.exit_reached.is_connected(_on_player_exit_reached):
					player.exit_reached.connect(_on_player_exit_reached)
			if player.has_signal("player_moved"):
				if not player.player_moved.is_connected(_on_player_moved):
					player.player_moved.connect(_on_player_moved)
			if player.has_method("update_visibility"):
				player.update_visibility()
				player.call_deferred("_reveal_on_spawn")
			emit_signal("player_spawned", player)

			# restore inventory if present
			if item.has("inventory"):
				var inv = item.get("inventory")
				var fixed_inv: Dictionary = {}

				for k in inv.keys():
					fixed_inv[int(k)] = inv[k]

				PlayerInventory.inventory = fixed_inv
				PlayerInventory._emit_changed()


func _obj_has_property(obj: Object, prop: String) -> bool:
	if obj == null:
		return false
	if not obj.has_method("get_property_list"):
		return false
	for p in obj.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func save_current_world() -> void:
	# Serialize dungeon floor and top tilemaps to user:// JSON so they can be restored later
	var payload: Dictionary = {}
	payload["world_index"] = world_index
	payload["floor"] = _serialize_tilemap(dungeon_floor)
	payload["top"] = _serialize_tilemap(dungeon_top)

	# entities
	if world_root != null and is_instance_valid(world_root):
		payload["entities"] = _serialize_entities()
	else:
		payload["entities"] = []

	# minimap
	if minimap != null:
		payload["minimap"] = _serialize_minimap(minimap)
	else:
		payload["minimap"] = {}

	# selected skills (persist player's chosen skills)
	if typeof(SkillState) != TYPE_NIL:
		payload["selected_skills"] = SkillState.selected_skills
	else:
		payload["selected_skills"] = []

	var path = "user://world_tilemap_save.json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("save_current_world: failed to open " + path)
		return
	f.store_string(JSON.stringify(payload, "  ", false))
	f.close()
	print("Saved world tilemaps + entities to: ", path)


func spawn_enemies(do_boss: bool) -> void:
	var data: Dictionary = EntityAutoload.item_data
	var settings: Dictionary = data.get("_settings", {})

	var max_weights = settings.get("max_total_weight_per_level", [])
	var max_weight: int = settings.get("default_max_total_weight", 30)

	if world_index < max_weights.size():
		max_weight = max_weights[world_index]

	# Tutorial override: immer 3
	#if world_index == -1:
	#max_weight = 2

	# --- Enemy Definitions sammeln ---
	var defs: Array[Dictionary] = []

	for k in data.keys():
		if str(k).begins_with("_"):
			continue

		var d: Dictionary = data[k]
		if d.get("entityCategory") != "enemy" and not do_boss:
			continue
		elif d.get("entityCategory") != "boss" and do_boss:
			continue

		# Tutorial-Welt: nur tutorial-Gegner spawnen
		# Normale Welten: keine tutorial-Gegner spawnen
		var is_tutorial_enemy = "tutorial" in d.get("behaviour", [])
		var is_tutorial_world = world_index == -1

		if is_tutorial_world and not is_tutorial_enemy:
			continue
		elif not is_tutorial_world and is_tutorial_enemy:
			continue

		# Alias auflösen
		if d.has("alias_of"):
			var base = data[d["alias_of"]]
			var merged = base.duplicate(true)
			for x in d.keys():
				merged[x] = d[x]
			d = merged

		d["_id"] = str(k)
		defs.append(d)

	# --- Wahrscheinlichkeiten ---
	var weights: Array[float] = []
	var total = 0.0

	for d in defs:
		var sr = d.get("spawnrate", {})
		var avg = (float(sr.get("min", 0)) + float(sr.get("max", 0))) * 0.5
		weights.append(avg)
		total += avg

	if total <= 0:
		for i in range(weights.size()):
			weights[i] = 1.0
		total = float(weights.size())

	# --- Spawn-Plan erstellen ---
	var rng = GlobalRNG.get_rng()
	rng.seed = GlobalRNG.next_seed()

	var current_weight = 0
	var spawn_plan = {}

	var roll: float
	var acc: float
	var chosen: int

	if do_boss:
		print("Should spawn boss")
		roll = rng.randf() * total
		acc = 0.0
		chosen = 0
		for j in range(defs.size()):
			acc += weights[j]
			if roll <= acc:
				chosen = j
				break
		var def = defs[chosen]
		spawn_enemy(
			def.get("sprite_type", "what"),
			def.get("behaviour", []),
			def.get("skills", []),
			def.get("stats", {}),
			true
		)
		print("Spawned boss!")
		return

	for _i in range(100):
		if current_weight >= max_weight:
			break

		# weighted pick
		roll = rng.randf() * total
		acc = 0.0
		chosen = 0

		for j in range(defs.size()):
			acc += weights[j]
			if roll <= acc:
				chosen = j
				break

		var def = defs[chosen]

		var sc = def.get("spawncount", {})
		var count = rng.randi_range(int(sc.get("min", 0)), int(sc.get("max", 1)))

		var w = int(def.get("weight", 1))
		var id = def["_id"]

		for _j in range(count):
			if current_weight + w > max_weight:
				break

			spawn_plan[id] = spawn_plan.get(id, 0) + 1
			current_weight += w

	# --- Enemies wirklich spawnen ---
	for id in spawn_plan.keys():
		var def = data[id]

		# Alias nochmal auflösen (für behaviour/sprite)
		if def.has("alias_of"):
			def = data[def["alias_of"]]

		for i in range(spawn_plan[id]):
			spawn_enemy(
				def.get("sprite_type", id),
				def.get("behaviour", []),
				def.get("skills", []),
				def.get("stats", {})
			)
			print("spawn: ", def.get("sprite_type", id))


func spawn_enemy(
	sprite_type: String, behaviour: Array, skills: Array, stats: Dictionary, boss: bool = false
) -> void:
	# default: spawn normal enemy
	var e = ENEMY_SCENE.instantiate()
	e.add_to_group("enemy")
	e.add_to_group("vision_objects")

	e.types = behaviour
	e.sprite_type = sprite_type
	e.abilities_this_has = skills
	e.boss = boss
	var hp = stats.get("hp", 1)
	var str = stats.get("str", 1)
	var def = stats.get("def", 1)

	# setup with Floor Tilemap
	e.setup(dungeon_floor, dungeon_top, hp, str, def, stats)

	# Enemies always in WorldRoot
	if world_root != null:
		world_root.add_child(e)
	else:
		add_child(e)


func spawn_player() -> void:
	# alte Player entfernen
	for n in get_tree().get_nodes_in_group("player"):
		if n != null and is_instance_valid(n):
			n.queue_free()

	var e: PlayerCharacter = PLAYER_SCENE.instantiate()
	e.name = "Player"
	# Floor setzen (einmal!)
	e.setup(dungeon_floor, dungeon_top, 20, 4, 0, {})
	e.fog_layer = fog_war_layer
	# pass dynamic flag and fog tile id to player for re-fogging
	if e.has_method("set"):
		e.set("dynamic_fog", fog_dynamic)
		e.set("fog_tile_id", fog_tile_id)
	# in WorldRoot hängen
	world_root.add_child(e)
	player = e

	# Ensure player is drawn above fog layer so player is visible
	if fog_war_layer != null:
		player.z_index = fog_war_layer.z_index + 10000000

	# minimap rein
	player.set_minimap(minimap)

	# Spawn Position
	var start_pos = Vector2i(2, 2)

	# Tutorial world: spawn at different position
	if minimap == null:
		start_pos = Vector2i(-18, 15)

	# erst tilemap, dann gridpos, dann position
	player.grid_pos = start_pos
	player.global_position = dungeon_floor.to_global(dungeon_floor.map_to_local(start_pos))
	player.add_to_group("player")

	# Signale verbinden
	if player.has_signal("exit_reached"):
		if not player.exit_reached.is_connected(_on_player_exit_reached):
			player.exit_reached.connect(_on_player_exit_reached)
	else:
		push_warning("player has no exit_reached signal")

	if player.has_signal("player_moved"):
		if not player.player_moved.is_connected(_on_player_moved):
			player.player_moved.connect(_on_player_moved)

	# WICHTIG: einmal initial Fog aufdecken
	if player.has_method("update_visibility"):
		player.update_visibility()
		# ensure reveal runs after any reparenting/initialization in this frame
		player.call_deferred("_reveal_on_spawn")
		emit_signal("player_spawned", player)


func get_world_tilemaps() -> Dictionary:
	var result: Dictionary = {
		"world_index": world_index,
		"dungeon_floor": dungeon_floor,
		"dungeon_top": dungeon_top,
	}
	return result


func _on_player_moved() -> void:
	if minimap == null or dungeon_floor == null or player == null:
		return

	# 1) Player -> Cell in FLOOR Tilemap
	var world_cell: Vector2i = dungeon_floor.local_to_map(
		dungeon_floor.to_local(player.global_position)
	)

	# 2) Nur echte Room-Layer checken (und Background/Full Layers skippen)
	for child in minimap.get_children():
		if not (child is TileMapLayer):
			continue

		var room_layer := child as TileMapLayer

		# --- HARD SKIP: Background / helper layers ---
		if room_layer.name == "MinimapBackground":
			continue

		# --- Optional: wenn du RoomLayer explizit markierst ---
		# Wenn du irgendwo room_layer.set_meta("is_room_layer", true) setzt,
		# kannst du diese Zeilen aktivieren und die Meta-Checks darunter entfernen.
		# if not room_layer.get_meta("is_room_layer", false):
		#     continue

		# --- Robust: ein RoomLayer hat normalerweise tile_origin oder room_rect Meta ---
		var has_origin := room_layer.has_meta("tile_origin")
		var has_rect := room_layer.has_meta("room_rect")
		if not has_origin and not has_rect:
			# kein RoomLayer -> skip (verhindert "alles revealed" bei Full-Layern)
			continue

		# RoomOrigin aus Meta (wie bei dir)
		var origin: Vector2i = room_layer.get_meta("tile_origin", Vector2i.ZERO)

		# Player Cell relativ zum RoomLayer
		var local_cell := world_cell - origin

		# Check ob wir wirklich auf einem Tile dieses RoomLayers stehen
		if room_layer.get_cell_source_id(local_cell) != -1:
			# minimap reveal (Room sichtbar schalten)
			room_layer.visible = true

			# Fog reveal nur für diesen Raum
			reveal_room_layer(room_layer)
			return


func load_world_from_file(idx: int) -> Dictionary:
	# Load saved world JSON from user:// and return instantiated TileMapLayer nodes
	var path = "user://world_tilemap_save.json"
	if not FileAccess.file_exists(path):
		push_error("load_world_from_file: save file not found: " + path)
		return {}

	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("load_world_from_file: failed to open " + path)
		return {}

	var text = f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	var payload: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		payload = parsed
	else:
		push_error("load_world_from_file: failed to parse save JSON")
		return {}

	var result: Dictionary = {}
	result["world_index"] = int(payload.get("world_index", idx))

	var floor_data = payload.get("floor", {})
	var top_data = payload.get("top", {})
	var entities_data = payload.get("entities", [])

	var floor_tm = _deserialize_tilemap(floor_data)
	var top_tm = _deserialize_tilemap(top_data)

	var minimap_node = null
	var minimap_data = payload.get("minimap", {})
	if typeof(minimap_data) == TYPE_DICTIONARY and not minimap_data.is_empty():
		minimap_node = _deserialize_minimap(minimap_data)

	result["floor"] = floor_tm
	result["top"] = top_tm
	result["entities"] = entities_data
	result["minimap"] = minimap_node

	# restore selected skills into the returned result so caller can apply them early
	result["selected_skills"] = payload.get("selected_skills", [])

	return result


func reveal_room_layer(room_layer: TileMapLayer) -> void:
	if fog_war_layer == null:
		return

	var origin: Vector2i = room_layer.get_meta("tile_origin", Vector2i.ZERO)
	var rect = room_layer.get_meta("room_rect", Rect2i(Vector2i.ZERO, Vector2i.ZERO))
	if rect.size == Vector2i.ZERO:
		# fallback: iterate used cells of the room layer
		for cell in room_layer.get_used_cells():
			var world_cell = origin + cell
			fog_war_layer.erase_cell(world_cell)
		return

	var counter = 0
	var yield_every = 300
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_cell = Vector2i(x, y)
			# skip empty tiles in the room
			if room_layer.get_cell_source_id(local_cell) == -1:
				continue
			var world_cell = origin + local_cell
			fog_war_layer.erase_cell(world_cell)
			counter += 1
			if counter % yield_every == 0:
				await get_tree().process_frame


# ---------------------------------------
# BATTLE
# ---------------------------------------
func instantiate_battle(player_node: Node, enemy: Node):
	if battle == null:
		print("instantiate_battle: creating battle instance")
		battle = BATTLE_SCENE.instantiate()
		battle.player = player_node
		battle.enemy = enemy

		battle.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		add_child(battle)

		# Connect signals and log results for debugging
		if battle.has_signal("player_victory"):
			# Connect to a wrapper that logs and then calls enemy_defeated
			var victory_callable_base = Callable(self, "_on_battle_player_victory")
			var victory_callable = victory_callable_base.bind(enemy)
			if not battle.is_connected("player_victory", victory_callable):
				# connect using Callable (already bound to enemy)
				battle.connect("player_victory", victory_callable)
				print("instantiate_battle: connected player_victory -> _on_battle_player_victory")
			else:
				print("instantiate_battle: player_victory already connected")
		else:
			print("instantiate_battle: battle has no signal player_victory")

		if battle.has_signal("player_loss"):
			# Connect to a wrapper that logs and then calls game_over
			var loss_callable = Callable(self, "_on_battle_player_loss")
			if not battle.is_connected("player_loss", loss_callable):
				battle.connect("player_loss", loss_callable)
				print("instantiate_battle: connected player_loss -> _on_battle_player_loss")
			else:
				print("instantiate_battle: player_loss already connected")
		else:
			print("instantiate_battle: battle has no signal player_loss")

		print("instantiate_battle: pausing tree to run battle")
		_set_tree_paused(true)


func find_merchants() -> Array[Vector2]:
	var merchants: Array[Vector2] = []

	var cells = dungeon_floor.get_used_cells()

	for cell in cells:
		var data = dungeon_floor.get_cell_tile_data(cell)

		if data == null:
			continue

		if not data.get_custom_data("merchant"):
			continue

		var right = cell + Vector2i(1, 0)
		var right_data = dungeon_floor.get_cell_tile_data(right)

		if right_data and right_data.get_custom_data("merchant"):
			var a = dungeon_floor.map_to_local(cell)
			var b = dungeon_floor.map_to_local(right)

			merchants.append((a + b) * 0.5)

	return merchants


func enemy_defeated(enemy):
	print("enemy_defeated: The battle is won - handler called")
	# Make sure game is unpaused first so UI can update
	var scene_tree = get_tree()
	if scene_tree != null and scene_tree.paused:
		print("enemy_defeated: unpausing tree")
		_set_tree_paused(false)

	if battle != null and is_instance_valid(battle):
		print("enemy_defeated: freeing battle UI")
		battle.call_deferred("queue_free")
		battle = null

	# If the defeated enemy was a boss, record victory so level-gating can proceed
	if enemy != null and is_instance_valid(enemy) and bool(enemy.boss):
		boss_win = true
		print("enemy_defeated: boss defeated -> boss_win set to true")

	if enemy != null and is_instance_valid(enemy):
		print("enemy_defeated: freeing enemy node")
		enemy.call_deferred("queue_free")

	if player != null and is_instance_valid(player):
		print("enemy_defeated: leveling up player")
		player.level_up()


func _on_battle_player_loss() -> void:
	# Now forward to existing game_over handler
	game_over()


func _on_battle_player_victory(enemy) -> void:
	print("_on_battle_player_victory: handler invoked — calling enemy_defeated")
	enemy_defeated(enemy)


func game_over():
	_set_tree_paused(false)
	var scene_tree = get_tree()
	if scene_tree != null:
		# Switch to preloaded death scene if available
		if typeof(DEATH_SCENE_PACKED) != TYPE_NIL:
			scene_tree.change_scene_to_packed(DEATH_SCENE_PACKED)
		else:
			scene_tree.change_scene_to_file(DEATH_SCENE)
	else:
		push_error("game_over: SceneTree is null; cannot change scene")


# -----------------------------------------------------
# JSON: Tutorial abgeschlossen?
# -----------------------------------------------------
func _has_completed_tutorial() -> bool:
	var path = "res://data/tutorialData.json"

	if not FileAccess.file_exists(path):
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_text: String = file.get_as_text()
		file.close()

		var parsed: Variant = JSON.parse_string(json_text)

		if typeof(parsed) == TYPE_DICTIONARY:
			var data: Dictionary = parsed
			return bool(data.get("tutorial_completed", false))

	return false


# -----------------------------------------------------
# JSON: Tutorial als abgeschlossen speichern
# -----------------------------------------------------
func _set_tutorial_completed() -> void:
	var path = "res://data/tutorialData.json"
	var data: Dictionary = {"tutorial_completed": true}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
