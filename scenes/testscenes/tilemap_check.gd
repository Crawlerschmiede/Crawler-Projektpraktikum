extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy_vampire_bat.tscn")
const BATTLE_SCENE := preload("res://scenes/battle.tscn")

# packed scene resource for the menu
@export var menu_scene: PackedScene

# A variable to hold the instance of the menu once it's created
var menu_instance: CanvasLayer = null
var battle: CanvasLayer = null

@onready var PlayerScene = preload("res://scenes/player-character-scene.tscn")
@onready var dungeon_tilemap: TileMapLayer = $TileMapLayer


func _ready() -> void:
	spawn_player()
	for i in range(3):
		spawn_enemy("what", ["hostile", "wallbound"])
	for i in range(3):
		spawn_enemy("bat", ["passive", "enemy_flying"])
	for i in range(3):
		spawn_enemy("skeleton", ["hostile", "enemy_walking"])


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


func spawn_enemy(sprite_type, types):
	var e = ENEMY_SCENE.instantiate()
	e.types = types
	e.sprite_type = sprite_type
	e.setup(dungeon_tilemap, 1, 1, 0)
	add_child(e)


func spawn_player():
	var e = PlayerScene.instantiate()
	e.name = "Player"
	e.setup(dungeon_tilemap, 10, 3, 0)
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


func game_over():
	get_tree().quit()
