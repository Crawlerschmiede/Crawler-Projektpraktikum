extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy_vampire_bat.tscn")
const BATTLE_SCENE := preload("res://scenes/battle.tscn")
const PLAYER_SCENE := preload("res://scenes/player-character-scene.tscn")
const LOOTBOX := preload("res://scenes/Lootbox/Lootbox.tscn")
const TRAP := preload("res://scenes/traps/Trap.tscn")
const MERCHANT := preload("res://scenes/entity/merchant.tscn")
const LOADING_SCENE:= preload("res://scenes/loadings_screen/loading_screen.tscn")
var loading_screen: CanvasLayer = null

@onready var backgroundtile = $TileMapLayer

@onready var minimap: TileMapLayer

@onready var generator1: Node2D = $World1
@onready var generator2: Node2D = $World2
@onready var generator3: Node2D = $World3

@onready var colorfilter: ColorRect = $ColorFilter

@export var menu_scene := preload("res://scenes/popup-menu.tscn")

# --- World state ---
var world_index: int = 0
var generators: Array[Node2D] = []

var world_root: Node2D = null
var dungeon_floor: TileMapLayer = null
var dungeon_top: TileMapLayer = null

var player: PlayerCharacter = null
var menu_instance: CanvasLayer = null
var battle: CanvasLayer = null

var switching_world := false


func _ready() -> void:
	generators = [generator1, generator2, generator3]
	await _load_world(world_index)


func _load_world(idx: int) -> void:
	get_tree().paused = true
	await _show_loading()

	# sorgt dafür, dass Loading immer weggeht
	var success := false

	_clear_world()

	if idx < 0 or idx >= generators.size():
		push_error("No more worlds left!")
		_hide_loading()
		get_tree().paused = false
		return

	var gen := generators[idx]

	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)

	var maps: Dictionary = await gen.get_random_tilemap()

	if maps.is_empty():
		push_error("Generator returned empty dictionary!")
		_hide_loading()
		get_tree().paused = false
		return

	dungeon_floor = maps.get("floor", null)
	dungeon_top = maps.get("top", null)
	minimap = maps.get("minimap", null)

	if dungeon_floor == null:
		push_error("Generator returned null floor tilemap!")
		_hide_loading()
		get_tree().paused = false
		return

	# minimap background
	if minimap != null and backgroundtile != null:
		var bg := backgroundtile.duplicate() as TileMapLayer
		bg.name = "MinimapBackground"
		bg.visibility_layer = 1 << 1
		bg.z_index = -100
		minimap.add_child(bg)
		minimap.move_child(bg, -1)

	if dungeon_floor.get_parent() == null:
		world_root.add_child(dungeon_floor)
	if dungeon_top != null and dungeon_top.get_parent() == null:
		world_root.add_child(dungeon_top)

	dungeon_floor.visibility_layer = 1
	update_color_filter()

	spawn_player()
	spawn_enemies()
	spawn_lootbox()
	spawn_traps()
	
	var merchants = find_merchants()
	
	for i in merchants:
		spawn_merchant_entity(i)
	
	_hide_loading()
	get_tree().paused = false

func spawn_merchant_entity(cords: Vector2) -> void:
	var e = MERCHANT.instantiate()
	e.add_to_group("merchant_entity")

	e.global_position = cords
	
	if world_root != null:
		world_root.add_child(e)
	else:
		add_child(e)

func _show_loading() -> void:
	if loading_screen == null:
		loading_screen = LOADING_SCENE.instantiate() as CanvasLayer
		add_child(loading_screen)

	loading_screen.layer = 100
	loading_screen.visible = true
	loading_screen.process_mode = Node.PROCESS_MODE_ALWAYS

	move_child(loading_screen, get_child_count() - 1)

	await get_tree().process_frame
	await get_tree().process_frame



func _hide_loading() -> void:
	if loading_screen != null and is_instance_valid(loading_screen):
		loading_screen.visible = false


func spawn_traps() -> void:
	if dungeon_floor == null or world_root == null:
		return

	# alte Lootboxen entfernen
	for c in world_root.get_children():
		if c != null and c.name.begins_with("Trap"):
			c.queue_free()

	# alle möglichen Lootbox-Spawns sammeln
	var candidates: Array[Vector2i] = []
	for cell in dungeon_floor.get_used_cells():
		var td := dungeon_floor.get_cell_tile_data(cell)
		if td == null:
			continue

		# Tileset Custom Data Bool
		if td.get_custom_data("trap_spawnable") == true:
			candidates.append(cell)

	if candidates.is_empty():
		print("⚠️ Keine lootbox_spawnable Tiles gefunden!")
		return

	# maximal 20 Lootboxen
	candidates.shuffle()
	var amount = min(20, candidates.size())

	for i in range(amount):
		var spawn_cell := candidates[i]
		var world_pos := dungeon_floor.to_global(dungeon_floor.map_to_local(spawn_cell))

		var loot := TRAP.instantiate() as Node2D
		loot.name = "Trap_%s" % i
		world_root.add_child(loot)
		loot.global_position = world_pos

		# ✅ Lootbox darf NICHT blockieren:
		#e_disable_lootbox_blocking(loot)

	print("✅ Lootboxen gespawnt:", amount)


func spawn_lootbox() -> void:
	if dungeon_floor == null or world_root == null:
		return

	# alte Lootboxen entfernen
	for c in world_root.get_children():
		if c != null and c.name.begins_with("Lootbox"):
			c.queue_free()

	# alle möglichen Lootbox-Spawns sammeln
	var candidates: Array[Vector2i] = []
	for cell in dungeon_floor.get_used_cells():
		var td := dungeon_floor.get_cell_tile_data(cell)
		if td == null:
			continue

		# Tileset Custom Data Bool
		if td.get_custom_data("lootbox_spawnable") == true:
			candidates.append(cell)

	if candidates.is_empty():
		print("⚠️ Keine lootbox_spawnable Tiles gefunden!")
		return

	# maximal 20 Lootboxen
	candidates.shuffle()
	var amount = min(20, candidates.size())

	for i in range(amount):
		var spawn_cell := candidates[i]
		var world_pos := dungeon_floor.to_global(dungeon_floor.map_to_local(spawn_cell))

		var loot := LOOTBOX.instantiate() as Node2D
		loot.name = "Lootbox_%s" % i
		world_root.add_child(loot)
		loot.global_position = world_pos

		# ✅ Lootbox darf NICHT blockieren:
		#e_disable_lootbox_blocking(loot)

	print("✅ Lootboxen gespawnt:", amount)


func _disable_lootbox_blocking(loot: Node) -> void:
	if loot == null:
		return

	# Falls Lootbox StaticBody2D / CharacterBody2D etc. hat: deaktivieren
	var bodies := loot.find_children("*", "PhysicsBody2D", true, false)
	for b in bodies:
		if b != null:
			b.set_deferred("collision_layer", 0)
			b.set_deferred("collision_mask", 0)

	# Falls Lootbox Area2D hat: darf triggern, aber nicht blocken
	var areas := loot.find_children("*", "Area2D", true, false)
	for a in areas:
		if a != null:
			# Area darf nur "triggern", aber nix blocken
			a.set_deferred("collision_layer", 0)
			a.set_deferred("collision_mask", 0)

	# Alle CollisionShapes deaktivieren (sicherster Weg)
	var shapes := loot.find_children("*", "CollisionShape2D", true, false)
	for s in shapes:
		if s != null:
			s.set_deferred("disabled", true)


func update_color_filter() -> void:
	if world_index == 0:
		colorfilter.visible = false
		return

	colorfilter.visible = true

	if world_index == 1:
		colorfilter.color = Color(1.0, 0.9, 0.3, 0.20)
	elif world_index == 2:
		colorfilter.color = Color(1.0, 0.2, 0.2, 0.25)


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
		world_root.queue_free()
		world_root = null

	dungeon_floor = null
	dungeon_top = null


func _on_player_exit_reached() -> void:
	# ✅ verhindert doppelte Trigger
	if switching_world:
		return
	switching_world = true

	print("EXIT reached -> switching world")

	world_index += 1
	await _load_world(world_index)

	switching_world = false


# ---------------------------------------
# UI / MENU
# ---------------------------------------
func _process(_delta) -> void:
	if Input.is_action_just_pressed("ui_menu"):
		toggle_menu()


func update_minimap_player_marker() -> void:
	if minimap == null or dungeon_floor == null or player == null:
		return

	var marker := minimap.get_node_or_null("PlayerMarker")
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

		get_tree().paused = true

		if menu_instance.has_signal("menu_closed"):
			menu_instance.menu_closed.connect(on_menu_closed)
	else:
		on_menu_closed()


func on_menu_closed():
	if menu_instance != null and is_instance_valid(menu_instance):
		menu_instance.queue_free()
		menu_instance = null
	get_tree().paused = false


# ---------------------------------------
# SPAWNING
# ---------------------------------------
func spawn_enemies() -> void:
	for i in range(3):
		spawn_enemy("what", ["hostile", "wallbound"])
	for i in range(3):
		spawn_enemy("bat", ["passive", "enemy_flying"])
	for i in range(3):
		spawn_enemy("skeleton", ["hostile", "enemy_walking"])
	for i in range(3):
		spawn_enemy("base_zombie", ["hostile", "enemy_walking", "burrowing"])


func spawn_enemy(sprite_type: String, behaviour: Array) -> void:
	# default: spawn normal enemy
	var e = ENEMY_SCENE.instantiate()
	e.add_to_group("enemy")
	e.types = behaviour
	e.sprite_type = sprite_type

	# setup with Floor Tilemap
	e.setup(dungeon_floor, 3, 1, 0)

	# Enemies always in WorldRoot
	if world_root != null:
		world_root.add_child(e)
	else:
		add_child(e)


func spawn_player() -> void:
	for n in get_tree().get_nodes_in_group("player"):
		if n != null and is_instance_valid(n):
			n.queue_free()
	var e: PlayerCharacter = PLAYER_SCENE.instantiate()
	e.name = "Player"

	e.setup(dungeon_floor, 10, 3, 0)
	e.add_to_group("player")
	world_root.add_child(e)
	player = e

	player.set_minimap(minimap)
	# Spawn Position
	var start_pos := Vector2i(2, 2)

	# erst tilemap, dann gridpos, dann position
	player.setup(dungeon_floor, 10, 3, 0)
	player.grid_pos = start_pos
	player.global_position = dungeon_floor.to_global(dungeon_floor.map_to_local(start_pos))
	player.add_to_group("player")

	# Exit-Signal verbinden
	if player.has_signal("exit_reached"):
		if not player.exit_reached.is_connected(_on_player_exit_reached):
			player.exit_reached.connect(_on_player_exit_reached)
			push_warning("player has no exit_reached signal")

	if player.has_signal("player_moved"):
		if not player.player_moved.is_connected(_on_player_moved):
			player.player_moved.connect(_on_player_moved)


func _on_player_moved() -> void:
	print("moved")
	if minimap == null or dungeon_floor == null or player == null:
		return
	print("moved1")
	# 1) Player -> Cell in FLOOR Tilemap
	var world_cell: Vector2i = dungeon_floor.local_to_map(
		dungeon_floor.to_local(player.global_position)
	)
	print("moved2")
	# 2) passende RoomLayer finden, deren tile_origin passt
	for child in minimap.get_children():
		if not (child is TileMapLayer):
			continue
		print(child.name)
		var room_layer := child as TileMapLayer

		# RoomOrigin steht im Namen: Room_x_y
		# oder du speicherst es als Meta beim Erstellen (besser)
		var origin: Vector2i = room_layer.get_meta("tile_origin", Vector2i.ZERO)

		# Player Cell relativ zum RoomLayer
		var local_cell := world_cell - origin

		if room_layer.get_cell_source_id(local_cell) != -1:
			print(room_layer.get_cell_source_id(local_cell))
			room_layer.visible = true
			return


# ---------------------------------------
# BATTLE
# ---------------------------------------
func instantiate_battle(player_node: Node, enemy: Node):
	if battle == null:
		battle = BATTLE_SCENE.instantiate()
		battle.player = player_node
		battle.enemy = enemy

		battle.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		add_child(battle)

		if battle.has_signal("player_victory"):
			battle.player_victory.connect(enemy_defeated.bind(enemy))
		if battle.has_signal("player_loss"):
			battle.player_loss.connect(game_over)

		get_tree().paused = true

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
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
		battle = null

	if enemy != null and is_instance_valid(enemy):
		enemy.queue_free()

	get_tree().paused = false

	if player != null and is_instance_valid(player):
		player.level_up()


func game_over():
	get_tree().quit()
