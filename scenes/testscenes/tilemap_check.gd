extends Node2D

# packed scene resource for the menu
@export var menu_scene: PackedScene
@onready var EnemyScene = preload("res://scenes/enemy_vampire_bat.tscn")
const BattleScene := preload("res://scenes/battle.tscn")
@onready var dungeon_tilemap = $TileMapLayer

# A variable to hold the instance of the menu once it's created
var menu_instance: CanvasLayer = null

func _ready() -> void:
	for i in range(10):
		spawn_enemy()

func _process(delta):
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
		
func spawn_enemy():
	var e = EnemyScene.instantiate()
	e.setup(dungeon_tilemap, 1, 1, 0)
	add_child(e)
	
func instantiate_battle(player:Node, enemy:Node):
	var battle = BattleScene.instantiate()
	battle.player = player
	battle.enemy = enemy
	# Pause overworld while battle runs
	
	battle.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(battle)
	get_tree().paused = true
