extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy_vampire_bat.tscn")
const BATTLE_SCENE := preload("res://scenes/battle.tscn")
const PLAYER_SCENE := preload("res://scenes/player-character-scene.tscn")

# packed scene resource for the menu
@export var menu_scene: PackedScene

# A variable to hold the instance of the menu once it's created
var menu_instance: CanvasLayer = null
var battle: CanvasLayer = null

@onready var generator1: Node2D = $World1
@onready var generator2: Node2D = $World2
@onready var generator3: Node2D = $World3

var generators: Array[Node2D] = []
var world_index: int = 0

var dungeon_tilemap: TileMapLayer = null
var player: PlayerCharacter = null


func _ready() -> void:
	generators = [generator1, generator2, generator3]
	await _load_world(world_index)


# ---------------------------------------
# ✅ WORLD LOAD / SWITCH (wie dein altes script)
# ---------------------------------------
func _load_world(idx: int) -> void:
	# Pause während load
	get_tree().paused = true

	_clear_world()

	if idx < 0 or idx >= generators.size():
		push_error("No more worlds left!")
		get_tree().paused = false
		return

	var gen := generators[idx]

	dungeon_tilemap = await gen.get_random_tilemap()
	if dungeon_tilemap == null:
		push_error("Generator returned null tilemap!")
		get_tree().paused = false
		return

	# ✅ tilemap wie in altem script: existiert und ist im tree
	add_child(dungeon_tilemap)

	# ✅ jetzt Player/Enemies wie früher
	spawn_player()
	spawn_enemies()

	get_tree().paused = false


func _clear_world() -> void:
	# battle weg
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
		battle = null

	# player weg
	if player != null and is_instance_valid(player):
		player.queue_free()
		player = null

	# enemies weg
	for n in get_tree().get_nodes_in_group("enemy"):
		if n != null and is_instance_valid(n):
			n.queue_free()

	# tilemap weg
	if dungeon_tilemap != null and is_instance_valid(dungeon_tilemap):
		dungeon_tilemap.queue_free()
	dungeon_tilemap = null


func _on_player_exit_reached() -> void:
	print("EXIT reached -> switching world")

	world_index += 1
	await _load_world(world_index)


# ---------------------------------------
# UI / MENU (unverändert)
# ---------------------------------------
func _process(_delta):
	if Input.is_action_just_pressed("ui_menu"):
		toggle_menu()


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
	if menu_instance != null:
		menu_instance.queue_free()
		menu_instance = null
		get_tree().paused = false


# ---------------------------------------
# SPAWNING (wie altes script)
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
	var e = ENEMY_SCENE.instantiate()
	e.add_to_group("enemy") # ✅ wichtig fürs löschen
	e.types = behaviour
	e.sprite_type = sprite_type

	# wie früher: setup + add_child
	add_child(e)
	e.setup(dungeon_tilemap, 3, 1, 0)


func spawn_player() -> void:
	var e: PlayerCharacter = PLAYER_SCENE.instantiate()
	e.name = "Player"

	add_child(e)
	e.setup(dungeon_tilemap, 10, 3, 0)

	player = e

	# ✅ exit signal verbinden (wie battle/menu)
	if player.has_signal("exit_reached"):
		if not player.exit_reached.is_connected(_on_player_exit_reached):
			player.exit_reached.connect(_on_player_exit_reached)


# ---------------------------------------
# BATTLE (wie altes script)
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


func enemy_defeated(enemy):
	if battle != null:
		battle.queue_free()
		battle = null
		enemy.queue_free()
		get_tree().paused = false
		player.level_up()


func game_over():
	get_tree().quit()
