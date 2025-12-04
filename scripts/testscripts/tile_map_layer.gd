extends TileMapLayer


func _ready():
	debug_print_tiles()


func debug_print_tiles():
	print("--- Tile Debug ---")
	for cell in get_used_cells():
		var tile_data = get_cell_tile_data(cell)
		if tile_data:
			var is_blocked = tile_data.get_custom_data("non_walkable")
			print(
				"Cell:",
				cell,
				" Global coordinates",
				map_to_local(cell),
				" | non_walkable =",
				is_blocked
			)
