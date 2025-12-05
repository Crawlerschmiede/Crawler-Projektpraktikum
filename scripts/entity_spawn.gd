extends Node

# --- Member variables ---
var grid_pos: Vector2i
var tilemap: TileMapLayer

# --- RNG for random placement on tiles ---
var rng := RandomNumberGenerator.new()


# Called when the node enters the scene tree for the first time.
func entity_spawn(tilemap: TileMapLayer):
	# Make sure the character starts perfectly aligned to the grid
	var possible_spawns = []
	for cell in tilemap.get_used_cells():
		var tile_data = tilemap.get_cell_tile_data(cell)
		if tile_data:
			var is_blocked = tile_data.get_custom_data("non_walkable")
			if not is_blocked:
				possible_spawns.append(cell)
	# Initialize grid position based on where the player starts
	var spawnpoint = possible_spawns[rng.randi_range(0, len(possible_spawns) - 1)]

	return tilemap.map_to_local(spawnpoint)
