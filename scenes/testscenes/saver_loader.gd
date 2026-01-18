class_name SaverLoader
extends Node

@onready var player = %Player
@onready var world_root = %WorldRoot

func save_game():
	var saved_game:SavedGame = SavedGame.new()
	
	saved_game.player_health = player.health
	saved_game.player_position = player.global_position
	
	var saved_data:Array[SavedData] = []
	get_tree().call_group("game_events", "on_save_game", saved_data)
	saved_game.saved_data = saved_data
	
	ResourceSaver.save(saved_game, "user://savegame.tres")
	
func load_game():
	var saved_game:SavedGame = load("user://savegame.tres") as SavedGame
	
	player.global_position = saved_game.player_position
	player.health = saved_game.player_health
