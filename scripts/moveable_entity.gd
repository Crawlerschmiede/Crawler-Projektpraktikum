class_name MoveableEntity

extends CharacterBody2D

# --- Constants ---
# The size of one tile in pixels
const TILE_SIZE: int = 16

# --- Member variables ---
var grid_pos: Vector2i
var tilemap: TileMapLayer = null
var latest_direction = Vector2i.DOWN
var is_moving: bool = false
var rng := RandomNumberGenerator.new()

@onready var detection_area: Area2D = $Area2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# --- Setup ---
func setup(tmap: TileMapLayer):
	tilemap = tmap


func super_ready(entity_type: String):
	if tilemap == null:
		push_error("❌ MoveableEntity hat keine TileMap! setup(tilemap) vergessen?")
		return

	if entity_type == "pc":
		grid_pos = Vector2i(2, 2)
		position = tilemap.map_to_local(grid_pos)
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


func check_collisions() -> void:
	for body in detection_area.get_overlapping_bodies():
		if body == self:
			continue
		if grid_pos == body.grid_pos:
			print(self.name, " overlapped with:", body.name, " on Tile ", grid_pos)


func _on_move_finished():
	is_moving = false
	check_collisions()


func is_cell_walkable(cell: Vector2i) -> bool:
	# Get the tile data from the TileMapLayer at the given cell
	var tile_data = tilemap.get_cell_tile_data(cell)
	if tile_data == null:
		return false  # No tile = not walkable (outside map)

	# Check for your custom property "non_walkable"
	if tile_data.get_custom_data("non_walkable") == true:
		return false

	return true
