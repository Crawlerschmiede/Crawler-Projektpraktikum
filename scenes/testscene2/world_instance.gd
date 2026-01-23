extends Node2D
class_name WorldInstance

const ENEMY_SCENE := preload("res://scenes/enemy_vampire_bat.tscn")
const PLAYER_SCENE := preload("res://scenes/player-character-scene.tscn")
const LOOTBOX := preload("res://scenes/Lootbox/Lootbox.tscn")

signal exit_reached

var dungeon_floor: TileMapLayer
var dungeon_top: TileMapLayer
var minimap: TileMapLayer
var player: PlayerCharacter

func load_from_generator(gen: Node) -> void:
	var maps: Dictionary = await gen.get_random_tilemap()

	dungeon_floor = maps.get("floor")
	dungeon_top = maps.get("top")
	minimap = maps.get("minimap")

	if dungeon_floor == null:
		push_error("WorldInstance: dungeon_floor null!")
		return

	add_child(dungeon_floor)
	if dungeon_top != null:
		add_child(dungeon_top)
	if minimap != null and minimap.get_parent() == null:
		add_child(minimap)

	dungeon_floor.visibility_layer = 1

	spawn_player()
	spawn_enemies()
	spawn_lootbox()


func spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)

	var start_pos := Vector2i(2,2)
	player.setup(dungeon_floor, 10, 3, 0)
	player.grid_pos = start_pos
	player.global_position = dungeon_floor.to_global(dungeon_floor.map_to_local(start_pos))
	player.set_minimap(minimap)

	if player.has_signal("exit_reached"):
		if not player.exit_reached.is_connected(_on_player_exit_reached):
			player.exit_reached.connect(_on_player_exit_reached)

func _on_player_exit_reached() -> void:
	emit_signal("exit_reached")


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
	e.add_to_group("enemy")
	e.types = behaviour
	e.sprite_type = sprite_type

	e.setup(dungeon_floor, 3, 1, 0)
	add_child(e)


func spawn_lootbox() -> void:
	var candidates: Array[Vector2i] = []

	for cell in dungeon_floor.get_used_cells():
		var td := dungeon_floor.get_cell_tile_data(cell)
		if td and td.get_custom_data("lootbox_spawnable") == true:
			candidates.append(cell)

	if candidates.is_empty():
		return

	candidates.shuffle()
	var amount = min(20, candidates.size())

	for i in range(amount):
		var spawn_cell := candidates[i]
		var world_pos := dungeon_floor.to_global(dungeon_floor.map_to_local(spawn_cell))

		var loot := LOOTBOX.instantiate()
		loot.name = "Lootbox_%s" % i
		add_child(loot)
		loot.global_position = world_pos
