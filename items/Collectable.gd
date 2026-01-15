extends Area2D

@export var item_name: String = "coin"
@export var amount: int = 1
@export var item_id: int = 0
@export var description: String = "A basic item"
@export var spawn_location: String = "anywhere"
@export var tilemap_path: NodePath

var rng := RandomNumberGenerator.new()

# --- Member variables ---
var grid_pos: Vector2i
var tilemap: TileMapLayer = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tilemap = get_node(tilemap_path)
	place_on_map()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func place_on_map():
	var possible_spawns = []
	for cell in tilemap.get_used_cells():
		var tile_data = tilemap.get_cell_tile_data(cell)
		if tile_data:
			var is_blocked = tile_data.get_custom_data("non_walkable")
			if not is_blocked:
				possible_spawns.append(cell)

	# Initialize grid position based on where the entity starts
	var spawnpoint = possible_spawns[rng.randi_range(0, len(possible_spawns) - 1)]
	if spawn_location == "anywhere":
		position = tilemap.map_to_local(spawnpoint)
		grid_pos = spawnpoint


func collect(player):
	player.add_to_inventory(item_name, amount)
	queue_free()
