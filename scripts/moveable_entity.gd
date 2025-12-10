class_name MoveableEntity

extends CharacterBody2D

# --- Constants ---
# The size of one tile in pixels
const TILE_SIZE: int = 16

# --- Exports ---
@export var tilemap_path: NodePath

# --- Member variables ---
var grid_pos: Vector2i
var tilemap: TileMapLayer
var latest_direction = Vector2i.DOWN
var is_moving: bool = false
var rng := RandomNumberGenerator.new()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Setup ---


func super_ready(entity_type: String):
	tilemap = get_node(tilemap_path)

	# Spawn logic for player character
	if entity_type == "pc":
		# TODO: make pc spawn at the current floor's entryway
		position = tilemap.map_to_local(Vector2i(2, 2))
		grid_pos = Vector2i(2, 2)
	# Spawn logic for enemies
	else:
		var possible_spawns = []

		for cell in tilemap.get_used_cells():
			var tile_data = tilemap.get_cell_tile_data(cell)
			if tile_data:
				var is_blocked = tile_data.get_custom_data("non_walkable")
				if not is_blocked:
					possible_spawns.append(cell)
			# TODO: add logic for fyling enemies, so they can enter certain tiles
			#if entity_type == "enemy_flying":
			#	add water/lava/floor trap tiles as possible spawns

		# Initialize grid position based on where the entity starts
		var spawnpoint = possible_spawns[rng.randi_range(0, len(possible_spawns) - 1)]
		position = tilemap.map_to_local(spawnpoint)
		grid_pos = spawnpoint


# --- Movement Logic ---


func move_to_tile(direction: Vector2i):
	if is_moving:
		return

	var target_cell = grid_pos + direction
	if not is_cell_walkable(target_cell):
		return

	is_moving = true
	grid_pos = target_cell
	var target_position = tilemap.map_to_local(grid_pos)

	var tween = get_tree().create_tween()
	tween.tween_property(self, "position", target_position, 0.15)
	tween.finished.connect(_on_move_finished)


func _on_move_finished():
	is_moving = false


func is_cell_walkable(cell: Vector2i) -> bool:
	# Get the tile data from the TileMapLayer at the given cell
	var tile_data = tilemap.get_cell_tile_data(cell)
	if tile_data == null:
		return false  # No tile = not walkable (outside map)

	# Check for your custom property "non_walkable"
	if tile_data.get_custom_data("non_walkable") == true:
		return false

	return true
