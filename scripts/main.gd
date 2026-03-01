extends Node2D

# gdlint: disable=max-file-lines

signal player_spawned

const ENEMY_SCENE := preload("res://scenes/entity/enemy.tscn")
const BATTLE_SCENE := preload("res://scenes/UI/battle.tscn")
const BATTLE_FLOW := preload("res://scripts/flow/battle_flow.gd")
const WORLD_FLOW := preload("res://scripts/flow/world_flow.gd")
const WORLD_LOAD_FLOW := preload("res://scripts/flow/world_load_flow.gd")
const WORLD_ENTITY_SPAWN_FLOW := preload("res://scripts/flow/world_entity_spawn_flow.gd")
const MINIMAP_REVEAL_FLOW := preload("res://scripts/flow/minimap_reveal_flow.gd")
const SAVE_FLOW := preload("res://scripts/flow/save_flow.gd")
const ENTITY_PERSISTENCE_FLOW := preload("res://scripts/flow/entity_persistence_flow.gd")
const ENEMY_SPAWN_FLOW := preload("res://scripts/flow/enemy_spawn_flow.gd")
const ManifestCore := preload("res://tools/manifest_generation_core.gd")
const PLAYER_SCENE := preload("res://scenes/entity/player-character-scene.tscn")
const LOOTBOX := preload("res://scenes/Interactables/Lootbox.tscn")
const TRAP := preload("res://scenes/Interactables/Trap.tscn")
const MERCHANT := preload("res://scenes/entity/merchant.tscn")
const LOADING_SCENE := preload("res://scenes/UI/loading_screen.tscn")
const SKILLTREE_SELECT_SCENE := preload("res://scenes/UI/skilltree-select-menu.tscn")
const SKILLTREE_UPGRADING_SCENE := preload("res://scenes/UI/skilltree-upgrading.tscn")
const START_SCENE := "res://scenes/UI/start-menu.tscn"
const DEATH_SCENE := "res://scenes/UI/death-screen.tscn"
const DEATH_SCENE_PACKED := preload("res://scenes/UI/death-screen.tscn")
const WIN_SCENE := "res://scenes/UI/won-screen.tscn"
const WIN_SCENE_PACKED := preload("res://scenes/UI/won-screen.tscn")
const SEWER_TILESET := "res://scenes/rooms/Rooms/roomtiles_2world.tres"
const TUTORIAL_ROOM := "res://scenes/rooms/Tutorial Rooms/tutorial_room.tscn"
const UI_MODAL_CONTROLLER := preload("res://scripts/UI/ui_modal_controller.gd")
@export var menu_scene := preload("res://scenes/UI/popup-menu.tscn")
@export var fog_tile_id: int = 0  # set this in the inspector to the fog-tile id in your tileset
@export var fog_dynamic: bool = true  # if true, areas that are no longer visible get fogged again
@export var world_music: Array[AudioStream] = []
# --- World state ---
var world_index: int = -1
var generators: Array[Node2D] = []

var world_root: Node2D = null
var dungeon_floor: TileMapLayer = null
var dungeon_top: TileMapLayer = null

var saved_maps: Dictionary = {}

var player: PlayerCharacter = null
var menu_instance: CanvasLayer = null
var battle_flow: RefCounted = null

var loading_screen: CanvasLayer = null

var world_flow: RefCounted = null
var world_load_flow: RefCounted = null
var world_entity_spawn_flow: RefCounted = null
var minimap_reveal_flow: RefCounted = null
var save_flow: RefCounted = null
var entity_persistence_flow: RefCounted = null
var enemy_spawn_flow: RefCounted = null

var boss_win: bool = false

@onready var backgroundtile = $TileMapLayer

@onready var minimap: TileMapLayer

@onready var generator1: Node2D = $World1
@onready var generator2: Node2D = $World2
@onready var generator3: Node2D = $World3

@onready var fog_war_layer = $FogWar


func _get_save_state() -> Node:
	if typeof(SaveState) != TYPE_NIL and SaveState != null:
		return SaveState
	var root := get_tree().root
	if root != null:
		return root.get_node_or_null("SaveState")
	return null


func _should_load_from_save() -> bool:
	var save_state := _get_save_state()
	if save_state == null:
		return false
	return bool(save_state.get("load_from_save"))


func _set_load_from_save(value: bool) -> void:
	var save_state := _get_save_state()
	if save_state == null:
		if value:
			push_warning("SaveState autoload is missing; cannot set load_from_save=true")
		return
	save_state.set("load_from_save", value)


func _emit_world_loaded(idx: int) -> void:
	if (
		typeof(GameEvents) != TYPE_NIL
		and GameEvents != null
		and GameEvents.has_method("emit_world_loaded")
	):
		GameEvents.emit_world_loaded(idx)
		return

	if typeof(AudioManager) != TYPE_NIL and AudioManager != null:
		AudioManager.play_world_music(idx)


func _emit_battle_started(enemy: Node) -> void:
	var is_boss_enemy := false
	if (
		typeof(AudioManager) != TYPE_NIL
		and AudioManager != null
		and AudioManager.has_method("is_boss_enemy")
	):
		is_boss_enemy = bool(AudioManager.is_boss_enemy(enemy))

	if (
		typeof(GameEvents) != TYPE_NIL
		and GameEvents != null
		and GameEvents.has_method("emit_battle_started")
	):
		GameEvents.emit_battle_started(enemy, is_boss_enemy)
		return

	if typeof(AudioManager) != TYPE_NIL and AudioManager != null:
		AudioManager.enter_battle(enemy)


func _emit_battle_ended(victory: bool, enemy: Node) -> void:
	var is_boss_enemy := false
	if (
		typeof(AudioManager) != TYPE_NIL
		and AudioManager != null
		and AudioManager.has_method("is_boss_enemy")
	):
		is_boss_enemy = bool(AudioManager.is_boss_enemy(enemy))

	if (
		typeof(GameEvents) != TYPE_NIL
		and GameEvents != null
		and GameEvents.has_method("emit_battle_ended")
	):
		GameEvents.emit_battle_ended(victory, enemy, is_boss_enemy)
		return

	if typeof(AudioManager) != TYPE_NIL and AudioManager != null:
		AudioManager.exit_battle()


func _emit_game_over() -> void:
	if (
		typeof(GameEvents) != TYPE_NIL
		and GameEvents != null
		and GameEvents.has_method("emit_game_over")
	):
		GameEvents.emit_game_over()
		return

	if typeof(AudioManager) != TYPE_NIL and AudioManager != null:
		AudioManager.clear_battle_state()


func _refresh_manifests_if_running_in_editor() -> void:
	if not OS.has_feature("editor"):
		return

	if not ManifestCore.write_all_manifests_to_disk():
		push_warning("main: failed to refresh manifests on editor run")


func _ready() -> void:
	_refresh_manifests_if_running_in_editor()
	UI_MODAL_CONTROLLER.set_debug_enabled(OS.is_debug_build())
	generators = [generator1, generator2, generator3]
	AudioManager.configure_world_music(world_music)
	battle_flow = BATTLE_FLOW.new()
	battle_flow.configure(self, BATTLE_SCENE)
	world_flow = WORLD_FLOW.new()
	world_load_flow = WORLD_LOAD_FLOW.new()
	world_entity_spawn_flow = WORLD_ENTITY_SPAWN_FLOW.new()
	minimap_reveal_flow = MINIMAP_REVEAL_FLOW.new()
	save_flow = SAVE_FLOW.new()
	entity_persistence_flow = ENTITY_PERSISTENCE_FLOW.new()
	enemy_spawn_flow = ENEMY_SPAWN_FLOW.new()
	enemy_spawn_flow.configure(ENEMY_SCENE)

	var battle_victory_handler := Callable(self, "_on_battle_player_victory")
	if not battle_flow.player_victory.is_connected(battle_victory_handler):
		battle_flow.player_victory.connect(battle_victory_handler)

	var battle_loss_handler := Callable(self, "_on_battle_player_loss")
	if not battle_flow.player_loss.is_connected(battle_loss_handler):
		battle_flow.player_loss.connect(battle_loss_handler)

	# If user requested loading from save, try to pre-load save data
	# BEFORE showing skill selection so previously selected skills are restored
	if _should_load_from_save():
		var early_loaded = load_world_from_file(0)
		if typeof(early_loaded) == TYPE_DICTIONARY and not early_loaded.is_empty():
			# restore selected skills into SkillState autoload if available
			if typeof(SkillState) != TYPE_NIL and SkillState != null:
				SkillState.selected_skills.clear()
				var selected_skills_raw: Variant = early_loaded.get("selected_skills", [])
				if typeof(selected_skills_raw) == TYPE_ARRAY:
					for skill in selected_skills_raw:
						SkillState.selected_skills.append(skill)
			# keep the loaded maps for later use in _load_world
			saved_maps = early_loaded
			world_index = int(early_loaded.get("world_index", 0))
	else:
		await _show_skilltree_select_menu()
		await _show_skilltree_upgrading_menu()

	# Tutorial prüfen (JSON: res://data/tutorialData.json)
	if _has_completed_tutorial() == false:
		await _load_tutorial_world()
		return
	if (
		_should_load_from_save()
		and (
			saved_maps == {}
			or not (typeof(saved_maps) == TYPE_DICTIONARY and saved_maps.has("floor"))
		)
	):
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
	elif (
		not _should_load_from_save()
		and (saved_maps == {} or not typeof(saved_maps) == TYPE_DICTIONARY)
	):
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


func _setup_fog_layer_for_current_world() -> void:
	if fog_war_layer == null or dungeon_floor == null or world_root == null:
		return

	if fog_war_layer.get_parent() != world_root:
		var old_parent = fog_war_layer.get_parent()
		if old_parent != null:
			old_parent.remove_child(fog_war_layer)
		world_root.add_child(fog_war_layer)
		fog_war_layer.position = dungeon_floor.position

	var base_z := 0
	if dungeon_top != null:
		base_z = dungeon_top.z_index
	elif dungeon_floor != null:
		base_z = dungeon_floor.z_index
	fog_war_layer.z_index = base_z + 10
	await init_fog_layer()


func _spawn_standard_world_entities(include_boss_enemy: bool) -> void:
	spawn_player()
	spawn_enemies(false)
	spawn_lootbox()
	spawn_traps()
	if include_boss_enemy:
		spawn_enemies(true)

	var merchants = find_merchants()
	for i in merchants:
		spawn_merchant_entity(i)


func _spawn_tutorial_entities_with_reveal() -> void:
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

			await _setup_fog_layer_for_current_world()

			if dungeon_floor != null:
				dungeon_floor.visibility_layer = 1

			_spawn_standard_world_entities(true)

			_hide_loading()
			get_tree().paused = false
			if is_instance_valid(tutorial_inst):
				tutorial_inst.queue_free()
			return

	# Fallback: Tutorial-Szene wie bisher parsen (TileMapLayer / Area2D etc.)
	var tutorial_scene = tutorial_inst as Node2D
	var extracted: Dictionary = {}
	if world_load_flow != null:
		extracted = world_load_flow.extract_tutorial_scene_to_world_root(tutorial_scene, world_root)

	if extracted.is_empty() or not bool(extracted.get("ok", false)):
		push_error(str(extracted.get("error", "Failed to extract tutorial scene")))
		_hide_loading()
		_set_tree_paused(false)
		return

	dungeon_floor = extracted.get("floor", null)
	dungeon_top = extracted.get("top", dungeon_floor)

	await _setup_fog_layer_for_current_world()

	dungeon_floor.visibility_layer = 1
	await _spawn_tutorial_entities_with_reveal()

	_hide_loading()
	_set_tree_paused(false)


func _load_world(idx: int) -> void:
	world_index = idx
	_emit_world_loaded(idx)
	_set_tree_paused(true)
	await _show_loading()

	_clear_world()

	if idx < 0 or idx >= generators.size():
		# No more worlds left -> show win screen (similar to game_over behavior)

		_hide_loading()
		_set_tree_paused(false)
		var scene_tree := get_tree()
		if scene_tree != null:
			if typeof(WIN_SCENE_PACKED) != TYPE_NIL:
				scene_tree.change_scene_to_packed(WIN_SCENE_PACKED)
			else:
				scene_tree.change_scene_to_file(WIN_SCENE)
		else:
			push_error("No more worlds left and SceneTree is null")
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
		if world_load_flow != null:
			world_load_flow.configure_saved_minimap(minimap, world_root, dungeon_floor)
	elif not _should_load_from_save():
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

	if dungeon_floor == null:
		push_error("Generator returned null floor tilemap!")
		_hide_loading()
		_set_tree_paused(false)
		return

	if world_load_flow != null:
		world_load_flow.apply_world_tileset_override(idx, SEWER_TILESET, dungeon_floor, dungeon_top)
		world_load_flow.attach_world_tilemaps(world_root, dungeon_floor, dungeon_top)

	await _setup_fog_layer_for_current_world()

	# -------------------------------------------------
	# Minimap Background
	# -------------------------------------------------
	if world_load_flow != null:
		world_load_flow.add_minimap_background(minimap, backgroundtile)

	dungeon_floor.visibility_layer = 1
	# -------------------------------------------------
	# Spawns / restore from save
	# -------------------------------------------------
	if saved_maps != null and typeof(saved_maps) == TYPE_DICTIONARY and saved_maps.has("entities"):
		_deserialize_entities(saved_maps.get("entities", []))
		# clear saved_maps so subsequent loads are fresh
		saved_maps = {}
	else:
		_spawn_standard_world_entities(true)

	# -------------------------------------------------
	# Fertig
	# -------------------------------------------------
	_hide_loading()
	_set_load_from_save(false)
	_set_tree_paused(false)


func spawn_merchant_entity(cords: Vector2) -> void:
	if world_entity_spawn_flow == null:
		return
	world_entity_spawn_flow.spawn_merchant_entity(cords, MERCHANT, world_root, self, world_index)


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
	if world_flow != null and world_flow.has_method("reset_transition_state"):
		world_flow.reset_transition_state()
	world_index = 0
	await _load_world(world_index)


func _hide_loading() -> void:
	if loading_screen != null and is_instance_valid(loading_screen):
		loading_screen.visible = false


func spawn_traps() -> void:
	if world_entity_spawn_flow == null:
		return
	world_entity_spawn_flow.spawn_traps(dungeon_floor, world_root, TRAP, world_index)


func spawn_lootbox() -> void:
	if world_entity_spawn_flow == null:
		return
	world_entity_spawn_flow.spawn_lootbox(dungeon_floor, world_root, LOOTBOX)


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
	if battle_flow != null and battle_flow.has_method("clear_battle"):
		battle_flow.clear_battle()

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

	# Reset global RNG to base seed so new-world generation is deterministic
	if typeof(GlobalRNG) != TYPE_NIL and GlobalRNG != null and GlobalRNG.has_method("reset"):
		GlobalRNG.reset()


func _on_player_exit_reached() -> void:
	if world_flow == null:
		push_warning("_on_player_exit_reached: world_flow is null")
		return

	world_index = await world_flow.try_advance_world(
		world_index, Callable(self, "_load_world"), Callable(self, "_set_tutorial_completed")
	)


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
	if entity_persistence_flow == null:
		return []
	return entity_persistence_flow.serialize_entities(world_root)


func _deserialize_entities(list_data: Array) -> void:
	if entity_persistence_flow == null:
		return
	if world_root == null:
		push_error("_deserialize_entities: world_root is null")
		return

	var scenes: Dictionary = {
		"enemy": ENEMY_SCENE,
		"merchant": MERCHANT,
		"lootbox": LOOTBOX,
		"trap": TRAP,
		"player": PLAYER_SCENE,
	}
	var defaults: Dictionary = {"fog_dynamic": fog_dynamic, "fog_tile_id": fog_tile_id}

	var loaded_player: Node = entity_persistence_flow.deserialize_entities(
		list_data,
		world_root,
		dungeon_floor,
		dungeon_top,
		fog_war_layer,
		minimap,
		scenes,
		defaults,
		self
	)

	if loaded_player is PlayerCharacter:
		player = loaded_player as PlayerCharacter


func save_current_world() -> void:
	# Serialize dungeon floor and top tilemaps to user:// JSON so they can be restored later
	if save_flow == null:
		push_error("save_current_world: save_flow is null")
		return

	var entities_payload: Array = []
	if world_root != null and is_instance_valid(world_root):
		entities_payload = _serialize_entities()

	var minimap_payload: Dictionary = {}
	if minimap != null:
		minimap_payload = _serialize_minimap(minimap)

	var selected_skills_payload: Array = []
	if typeof(SkillState) != TYPE_NIL:
		selected_skills_payload = SkillState.selected_skills

	var payload: Dictionary = save_flow.build_save_payload(
		world_index,
		_serialize_tilemap(dungeon_floor),
		_serialize_tilemap(dungeon_top),
		entities_payload,
		minimap_payload,
		selected_skills_payload
	)

	if not save_flow.write_payload(payload):
		return

	print("Saved world tilemaps + entities to: ", save_flow.SAVE_PATH)


func spawn_enemies(do_boss: bool) -> void:
	if enemy_spawn_flow == null:
		return

	var data: Dictionary = EntityAutoload.item_data
	enemy_spawn_flow.spawn_enemies(
		do_boss, world_index, data, dungeon_floor, dungeon_top, world_root, self
	)


func spawn_enemy(
	sprite_type: String,
	behaviour: Array,
	skills: Array,
	stats: Dictionary,
	xp: int,
	boss: bool = false
) -> void:
	if enemy_spawn_flow == null:
		return
	enemy_spawn_flow.spawn_enemy(
		sprite_type,
		behaviour,
		skills,
		stats,
		xp,
		dungeon_floor,
		dungeon_top,
		world_root,
		self,
		boss
	)


func spawn_player() -> void:
	# alte Player entfernen
	for n in get_tree().get_nodes_in_group("player"):
		if n != null and is_instance_valid(n):
			n.queue_free()

	var e: PlayerCharacter = PLAYER_SCENE.instantiate()
	e.name = "Player"
	# Floor setzen (einmal!)
	e.setup(dungeon_floor, dungeon_top, 10, 3, 0, {})
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

	if entity_persistence_flow != null:
		entity_persistence_flow.connect_player_signals(self, player, true)

	# WICHTIG: einmal initial Fog aufdecken
	if player.has_method("update_visibility") and entity_persistence_flow != null:
		entity_persistence_flow.update_player_visibility(player)
		emit_signal("player_spawned", player)


func get_world_tilemaps() -> Dictionary:
	var result: Dictionary = {
		"world_index": world_index,
		"dungeon_floor": dungeon_floor,
		"dungeon_top": dungeon_top,
	}
	return result


func _on_player_moved() -> void:
	if minimap_reveal_flow == null:
		return
	minimap_reveal_flow.on_player_moved(minimap, dungeon_floor, player, fog_war_layer, get_tree())


func load_world_from_file(idx: int) -> Dictionary:
	# Load saved world JSON from user:// and return instantiated TileMapLayer nodes
	if save_flow == null:
		push_error("load_world_from_file: save_flow is null")
		return {}

	var payload: Dictionary = save_flow.read_payload()
	if payload.is_empty():
		return {}

	return save_flow.build_loaded_world_result(
		payload, idx, Callable(self, "_deserialize_tilemap"), Callable(self, "_deserialize_minimap")
	)


# ---------------------------------------
# BATTLE
# ---------------------------------------
func instantiate_battle(player_node: Node, enemy: Node):
	if battle_flow == null:
		push_warning("instantiate_battle: battle_flow is null")
		return
	if battle_flow.has_active_battle():
		return

	print("instantiate_battle: creating battle instance")
	battle_flow.start_battle(player_node, enemy)
	if not battle_flow.has_active_battle():
		push_warning("instantiate_battle: failed to create battle instance")
		return

	_emit_battle_started(enemy)
	print("instantiate_battle: pausing tree to run battle")
	_set_tree_paused(true)


func find_merchants() -> Array[Vector2]:
	if world_entity_spawn_flow == null:
		return []
	return world_entity_spawn_flow.find_merchants(dungeon_floor)


func enemy_defeated(enemy):
	print("enemy_defeated: The battle is won - handler called")
	# Make sure game is unpaused first so UI can update
	var scene_tree := get_tree()
	var gained_xp = 0
	if scene_tree != null and scene_tree.paused:
		print("enemy_defeated: unpausing tree")
		_set_tree_paused(false)

	if battle_flow != null and battle_flow.has_active_battle():
		print("enemy_defeated: freeing battle UI")
		battle_flow.clear_battle()

	_emit_battle_ended(true, enemy)

	# If the defeated enemy was a boss, record victory so level-gating can proceed
	if enemy != null and is_instance_valid(enemy) and AudioManager.is_boss_enemy(enemy):
		boss_win = true
		print("enemy_defeated: boss defeated -> boss_win set to true")

	if enemy != null and is_instance_valid(enemy):
		gained_xp = enemy.xp
		print("enemy_defeated: freeing enemy node")
		enemy.call_deferred("queue_free")

	if player != null and is_instance_valid(player):
		print("enemy_defeated: leveling up player")
		print("player shall gain xp: ", gained_xp)
		SkillState.current_xp += gained_xp
		if SkillState.next_necessary_xp < SkillState.current_xp:
			SkillState.current_xp = SkillState.current_xp - SkillState.next_necessary_xp
			SkillState.next_necessary_xp *= 2
			await _show_skilltree_upgrading_menu()
			player.level_up()


func _on_battle_player_loss() -> void:
	# Now forward to existing game_over handler
	game_over()


func _on_battle_player_victory(enemy) -> void:
	print("_on_battle_player_victory: handler invoked — calling enemy_defeated")
	enemy_defeated(enemy)


func game_over():
	_emit_game_over()
	if battle_flow != null and battle_flow.has_active_battle():
		battle_flow.clear_battle()
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
