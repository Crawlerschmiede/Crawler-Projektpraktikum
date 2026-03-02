extends Node2D

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
const UI_OVERLAY_COORDINATOR := preload("res://scripts/flow/ui_overlay_coordinator.gd")
const WORLD_LOADING_COORDINATOR := preload("res://scripts/flow/world_loading_coordinator.gd")
const SPAWN_COORDINATOR := preload("res://scripts/flow/spawn_coordinator.gd")
const SAVE_SERIALIZER := preload("res://scripts/flow/save_serializer.gd")
const GAME_EVENT_GATEWAY := preload("res://scripts/flow/game_event_gateway.gd")
const PERSISTENCE_COORDINATOR := preload("res://scripts/flow/persistence_coordinator.gd")
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
const TUTORIAL_WORLD_INDEX := -1
const TUTORIAL_STATE_PATH_USER := "user://tutorialData.json"
const TUTORIAL_STATE_PATH_RES := "res://data/tutorialData.json"
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
var ui_overlay_coordinator: RefCounted = null
var world_loading_coordinator: RefCounted = null
var spawn_coordinator: RefCounted = null
var save_serializer: RefCounted = null
var game_event_gateway: RefCounted = null
var persistence_coordinator: RefCounted = null

var boss_win: bool = false

@onready var backgroundtile = $TileMapLayer

@onready var minimap: TileMapLayer

@onready var music_player: AudioStreamPlayer = $MusicPlayer
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
	if save_state != null:
		if save_state.has_method("should_load_from_save"):
			return bool(save_state.should_load_from_save())
		if bool(save_state.get("load_from_save")):
			return true
	return false


func _set_load_from_save(value: bool) -> void:
	var save_state := _get_save_state()
	if save_state == null:
		if value:
			push_warning("SaveState autoload is missing; cannot set load_from_save=true")
		return

	if save_state.has_method("set_should_load_from_save"):
		save_state.set_should_load_from_save(value)
	else:
		save_state.set("load_from_save", value)


func _restore_skill_state_from_loaded(loaded_data: Dictionary) -> void:
	if typeof(SkillState) == TYPE_NIL or SkillState == null:
		return

	if SkillState.has_method("reset"):
		SkillState.reset()

	var skill_state_raw: Variant = loaded_data.get("skill_state", {})
	if (
		typeof(skill_state_raw) == TYPE_DICTIONARY
		and not (skill_state_raw as Dictionary).is_empty()
	):
		if SkillState.has_method("import_state"):
			SkillState.import_state(skill_state_raw)
		return

	SkillState.selected_skills.clear()
	var selected_skills_raw: Variant = loaded_data.get("selected_skills", [])
	if typeof(selected_skills_raw) == TYPE_ARRAY:
		for skill in selected_skills_raw:
			SkillState.selected_skills.append(str(skill))


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
	ui_overlay_coordinator = UI_OVERLAY_COORDINATOR.new()
	spawn_coordinator = SPAWN_COORDINATOR.new()
	spawn_coordinator.configure(self, world_entity_spawn_flow, enemy_spawn_flow)
	world_loading_coordinator = WORLD_LOADING_COORDINATOR.new()
	world_loading_coordinator.configure(self, world_load_flow)
	save_serializer = SAVE_SERIALIZER.new()
	game_event_gateway = GAME_EVENT_GATEWAY.new()
	persistence_coordinator = PERSISTENCE_COORDINATOR.new()
	persistence_coordinator.configure(self, save_flow, save_serializer, entity_persistence_flow)

	var battle_victory_handler := Callable(self, "_on_battle_player_victory")
	if not battle_flow.player_victory.is_connected(battle_victory_handler):
		battle_flow.player_victory.connect(battle_victory_handler)

	var battle_loss_handler := Callable(self, "_on_battle_player_loss")
	if not battle_flow.player_loss.is_connected(battle_loss_handler):
		battle_flow.player_loss.connect(battle_loss_handler)

	# If user requested loading from save, try to pre-load save data
	# BEFORE showing skill selection so previously selected skills are restored
	if _should_load_from_save():
		var early_loaded: Dictionary = {}
		if persistence_coordinator != null:
			early_loaded = persistence_coordinator.load_world_from_file(0)
		if typeof(early_loaded) == TYPE_DICTIONARY and not early_loaded.is_empty():
			_restore_skill_state_from_loaded(early_loaded)
			# keep the loaded maps for later use in _load_world
			saved_maps = early_loaded
			world_index = int(early_loaded.get("world_index", 0))
	else:
		await _show_skilltree_select_menu()
		await _show_skilltree_upgrading_menu()

	# Tutorial prüfen (user://tutorialData.json, fallback: res://data/tutorialData.json)
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
		var loaded: Dictionary = {}
		if persistence_coordinator != null:
			loaded = persistence_coordinator.load_world_from_file(0)
		if loaded == {}:
			push_error(
				"_ready: requested load_from_save but load failed; falling back to new world"
			)
			world_index = 0
		else:
			_restore_skill_state_from_loaded(loaded)
			saved_maps = loaded
			world_index = int(loaded.get("world_index", 0))
	elif (
		not _should_load_from_save()
		and (saved_maps == {} or not typeof(saved_maps) == TYPE_DICTIONARY)
	):
		world_index = 0

	await _load_world(world_index)


func _show_skilltree_select_menu() -> void:
	if ui_overlay_coordinator == null:
		push_warning("_show_skilltree_select_menu: ui_overlay_coordinator is null")
		return
	await ui_overlay_coordinator.show_skilltree_select_menu(self, SKILLTREE_SELECT_SCENE)


func _show_skilltree_upgrading_menu() -> void:
	if ui_overlay_coordinator == null:
		push_warning("_show_skilltree_upgrading_menu: ui_overlay_coordinator is null")
		return
	await ui_overlay_coordinator.show_skilltree_upgrading_menu(self, SKILLTREE_UPGRADING_SCENE)


func _set_tree_paused(value: bool) -> void:
	var scene_tree = get_tree()
	if scene_tree != null:
		scene_tree.paused = value
	else:
		push_warning("_set_tree_paused: SceneTree is null; ignored")


func _load_tutorial_world() -> void:
	if world_loading_coordinator == null:
		push_warning("_load_tutorial_world: world_loading_coordinator is null")
		return
	await world_loading_coordinator.load_tutorial_world(TUTORIAL_ROOM)


func _load_world(idx: int) -> void:
	if world_loading_coordinator == null:
		push_warning("_load_world: world_loading_coordinator is null")
		return
	await world_loading_coordinator.load_world(idx, generators)


func _show_start() -> void:
	if ui_overlay_coordinator == null:
		push_warning("_show_start: ui_overlay_coordinator is null")
		return
	await ui_overlay_coordinator.show_start(
		self, START_SCENE, Callable(self, "_on_start_new_pressed")
	)


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
			if persistence_coordinator == null:
				push_error("toggle_menu: persistence_coordinator is null; save unavailable")
				return
			var cb = Callable(persistence_coordinator, "save_current_world")
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


func spawn_enemies(do_boss: bool) -> void:
	if spawn_coordinator == null:
		return
	spawn_coordinator.spawn_enemies(do_boss, world_index, dungeon_floor, dungeon_top, self)


func spawn_enemy(
	sprite_type: String,
	behaviour: Array,
	skills: Array,
	stats: Dictionary,
	xp: int,
	boss: bool = false
) -> void:
	if spawn_coordinator == null:
		return
	spawn_coordinator.spawn_enemy(
		sprite_type, behaviour, skills, stats, xp, dungeon_floor, dungeon_top, self, boss
	)


func spawn_player() -> void:
	if spawn_coordinator == null:
		return
	player = spawn_coordinator.spawn_player(
		PLAYER_SCENE,
		dungeon_floor,
		dungeon_top,
		fog_war_layer,
		minimap,
		fog_dynamic,
		fog_tile_id,
		entity_persistence_flow,
		self
	)


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

	if game_event_gateway != null:
		game_event_gateway.emit_battle_started(enemy)
	print("instantiate_battle: pausing tree to run battle")
	_set_tree_paused(true)


func find_merchants() -> Array[Vector2]:
	if spawn_coordinator == null:
		return []
	return spawn_coordinator.find_merchants(dungeon_floor)


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

	if game_event_gateway != null:
		game_event_gateway.emit_battle_ended(true, enemy)

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
	if game_event_gateway != null:
		game_event_gateway.emit_game_over()
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
	var paths := [TUTORIAL_STATE_PATH_USER, TUTORIAL_STATE_PATH_RES]
	for path in paths:
		if not FileAccess.file_exists(path):
			continue

		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue

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
	var data: Dictionary = {"tutorial_completed": true}

	var file = FileAccess.open(TUTORIAL_STATE_PATH_USER, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to persist tutorial completion state to user://")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
