extends CanvasLayer

@onready var enemy_marker = $Battle_root/EnemyPosition
@onready var player_marker = $Battle_root/PlayerPosition
@onready var combat_tilemap = $Battle_root/TileMapLayer
@onready var used_cells: Array[Vector2i] = combat_tilemap.get_used_cells()
@onready var skill_ui = $Battle_root/ItemList


@export var player:Node
@export var enemy:Node


signal player_loss
signal player_victory


var player_gridpos:Vector2i
var tile_modifiers: Dictionary = {}


var enemy_sprite
var player_sprite

func _ready():
	enemy_sprite = create_battle_sprite(enemy)
	player_sprite = create_battle_sprite(player)
	player_sprite.animation = "idle_up"
	enemy_marker.add_child(enemy_sprite)
	player_gridpos = combat_tilemap.local_to_map(player_marker.position)
	combat_tilemap.add_child(player_sprite)
	player_sprite.position = combat_tilemap.map_to_local(player_gridpos)
	skill_ui.setup(player, enemy, self)
	if skill_ui.has_signal("player_turn_done"):
		# Ensure the connection is safe and only happens once
		skill_ui.player_turn_done.connect(enemy_turn)
	enemy.decide_attack()
	enemy_prepare_turn()

	
	
func create_battle_sprite(from_actor: CharacterBody2D) -> AnimatedSprite2D:
	var source_sprite := from_actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert(source_sprite)

	var battle_sprite := AnimatedSprite2D.new()

	# Copy visuals
	battle_sprite.sprite_frames = source_sprite.sprite_frames
	battle_sprite.animation = source_sprite.animation
	battle_sprite.frame = source_sprite.frame
	battle_sprite.flip_h = source_sprite.flip_h
	battle_sprite.flip_v = source_sprite.flip_v
	battle_sprite.scale = source_sprite.scale

	battle_sprite.play()

	return battle_sprite
	
func enemy_prepare_turn():
	tile_modifiers.clear() #TODO VERY low tech, just removes everything, works fine for 1-turn effects, but anything else'll need something more complex
	print(enemy, " prepares its Skill ", enemy.chosen.name, "!")
	enemy.chosen.prep_skill(enemy, player, self)
	
func enemy_turn():
	var over = check_victory()
	if !over:
		print(enemy, " activates its Skill ", enemy.chosen.name, "!")
		enemy.chosen.activate_skill(enemy, player, self)
		enemy.decide_attack()
		enemy_prepare_turn()
		skill_ui.player_turn=true
		check_victory()
	
func check_victory():
	if enemy.HP <=0:
		player_victory.emit()
		return true
	if player.HP<=0:
		player_loss.emit()
		return true
	return false
	
func cell_exists(cell: Vector2i) -> bool:
	# Get the tile data from the TileMapLayer at the given cell
	var tile_data = combat_tilemap.get_cell_tile_data(cell)
	if tile_data == null:
		return false  # No tile = not walkable (outside map)
	return true

func move_player(direction:String, distance:int):
	if player_sprite == null:
		return

	var delta := Vector2i.ZERO
	match direction:
		"L":
			delta = Vector2i(-distance, 0)
		"R":
			delta = Vector2i(distance, 0)
		"U":
			delta = Vector2i(0, -distance)
		"D":
			delta = Vector2i(0, distance)
		_:
			return

	var new_cell := player_gridpos + delta
	
	if !cell_exists(new_cell):
		return
	player_gridpos = new_cell
	player_sprite.position = combat_tilemap.map_to_local(player_gridpos)
	
func apply_danger_zones(mult, pos, dur, direction):
	var mult_type ="dmg_mult_"+direction
	if pos == "player_x":
		for tile in used_cells:
			if tile.x == player_gridpos.x:
				tile_modifiers[tile] = {
					mult_type: mult
				}
	elif pos == "player_y":
		for tile in used_cells:
			if tile.y == player_gridpos.y:
				tile_modifiers[tile] = {
					mult_type: mult
				}
	elif "x" in pos:
		var parts = pos.split("=")
		var min_x = 99999999999999
		for tile in used_cells:
			if tile.x<min_x:
				min_x =tile.x
		for tile in used_cells:
			if tile.x == min_x+int(parts[1]):
				tile_modifiers[tile] = {
					mult_type: mult
				}
	elif "y" in pos:
		var parts = pos.split("=")
		print("parts: ", parts)
		var min_y = 99999999999999
		for tile in used_cells:
			if tile.y<min_y:
				min_y =tile.y
		for tile in used_cells:
			if tile.y == min_y+int(parts[1]):
				tile_modifiers[tile] = {
					mult_type: mult
				}
				
		
