extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy_vampire_bat.tscn")
const BATTLE_SCENE := preload("res://scenes/battle.tscn")

# packed scene resource for the menu
@export var menu_scene: PackedScene

@export var lootbox_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var lootbox_spawn_chance := 0.5
@export var lootbox_max_count := 50


# A variable to hold the instance of the menu once it's created
var menu_instance: CanvasLayer = null
var battle: CanvasLayer = null

@onready var PlayerScene = preload("res://scenes/player-character-scene.tscn")
@onready var dungeon_tilemap: TileMapLayer = $TileMapLayer

var player: PlayerCharacter


func _ready() -> void:
	spawn_lootboxes_from_tiles(dungeon_tilemap)
	spawn_player()
	for i in range(3):
		spawn_enemy("what", ["hostile", "wallbound"])
	for i in range(3):
		spawn_enemy("bat", ["passive", "enemy_flying"])
	for i in range(3):
		spawn_enemy("skeleton", ["hostile", "enemy_walking"])
	for i in range(3):
		spawn_enemy("base_zombie", ["hostile", "enemy_walking", "burrowing"])


func _process(_delta):
	# Check if the 'M' key is pressed
	if Input.is_action_just_pressed("ui_menu"):
		toggle_menu()


func toggle_menu():
	if menu_instance == null:
		# Create and add the menu (As before)
		menu_instance = menu_scene.instantiate()
		add_child(menu_instance)

		# Pause the game (As before)
		get_tree().paused = true

		# Connect the menu's custom signal to our closing function
		if menu_instance.has_signal("menu_closed"):
			# Ensure the connection is safe and only happens once
			menu_instance.menu_closed.connect(on_menu_closed)

	else:
		on_menu_closed()


func on_menu_closed():
	if menu_instance != null:
		# 1. Remove the menu from the scene tree and free its memory
		menu_instance.queue_free()

		# 2. Reset the reference
		menu_instance = null

		# 3. Unpause the game
		get_tree().paused = false


func spawn_enemy(sprite_type, behaviour):
	var e = ENEMY_SCENE.instantiate()
	e.types = behaviour
	e.sprite_type = sprite_type
	e.setup(dungeon_tilemap, 3, 1, 0)
	add_child(e)


func spawn_player():
	var e = PlayerScene.instantiate()
	e.name = "Player"
	e.setup(dungeon_tilemap, 10, 3, 0)
	player = e
	add_child(e)


func instantiate_battle(player: Node, enemy: Node):
	if battle == null:
		battle = BATTLE_SCENE.instantiate()
		battle.player = player
		battle.enemy = enemy
		# Pause overworld while battle runs

		battle.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		add_child(battle)
		# Connect the menu's custom signal to our closing function
		if battle.has_signal("player_victory"):
			# Ensure the connection is safe and only happens once
			battle.player_victory.connect(enemy_defeated.bind(enemy))
		if battle.has_signal("player_loss"):
			# Ensure the connection is safe and only happens once
			battle.player_loss.connect(game_over)
		get_tree().paused = true


func enemy_defeated(enemy):
	if battle != null:
		battle.queue_free()
		battle = null
		enemy.queue_free()
		get_tree().paused = false
		player.level_up()

func spawn_lootboxes_from_tiles(tilemap: TileMapLayer) -> void:
	if lootbox_scene == null:
		push_error("lootbox_scene ist NULL")
		return
	if tilemap == null:
		push_error("tilemap ist NULL")
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var spawned := 0
	for cell in tilemap.get_used_cells():
		var can_spawn := false

		if spawned >= lootbox_max_count:
			break

		var td := tilemap.get_cell_tile_data(cell)
		
		if td.get_custom_data("lootbox_spawnable") != null:
			can_spawn = bool(td.get_custom_data("lootbox_spawnable"))

		if not can_spawn:
			continue
			
		if td == null:
			continue

		# optional: nur auf begehbaren Tiles
		if bool(td.get_custom_data("non_walkable")):
			continue

		# dein Flag aus dem TileSet
		if not td.get_custom_data("lootbox_spawnable") == true:
			continue
		print("lootbox_spawnable")

		# 50% Chance
		if rng.randf() > lootbox_spawn_chance:
			continue

		var inst := lootbox_scene.instantiate() as Node2D
		add_child(inst)

		# Spawn genau auf der Tile-Mitte
		inst.global_position = tilemap.to_global(tilemap.map_to_local(cell))

		spawned += 1

	print("✔ Lootboxen gespawnt:", spawned)

func game_over():
	get_tree().quit()
