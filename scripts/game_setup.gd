extends Node2D


@onready var EnemyScene = preload("res://scenes/enemy_vampire_bat.tscn")
@onready var dungeon_tilemap = $TileMapLayer

func spawn_enemy():
	var e = EnemyScene.instantiate()
	e.setup(dungeon_tilemap)
	add_child(e)
	
func _ready() -> void:
	for i in range(10):
		spawn_enemy()
