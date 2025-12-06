extends CharacterBody2D

# --- Constants ---
# The size of one tile in pixels
const TILE_SIZE: int = 16
# Time (in seconds) the character pauses on a tile before taking the next step
const STEP_COOLDOWN: float = 0.15

# --- Exports ---
@export var tilemap_path: NodePath

# --- Member variables ---
var grid_pos: Vector2i
var tilemap: TileMapLayer
var latest_direction = Vector2i.DOWN

var inventory := {}

# Flag to prevent movement while the character is currently moving (Tween is active)
var is_moving: bool = false

# The timer used to track when the next move is allowed
var step_timer: float = 0.1
var rng := RandomNumberGenerator.new()

# Initialize onready vars after member variables per gdlint order
@onready var tween := get_tree().create_tween()
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Setup ---


func _ready():
	# Make sure the character starts perfectly aligned to the grid
	tilemap = get_node(tilemap_path)
	var possible_spawns = []
	for cell in tilemap.get_used_cells():
		var tile_data = tilemap.get_cell_tile_data(cell)
		if tile_data:
			var is_blocked = tile_data.get_custom_data("non_walkable")
			if not is_blocked:
				possible_spawns.append(cell)
	# Initialize grid position based on where the player starts
	var spawnpoint = possible_spawns[rng.randi_range(0, len(possible_spawns) - 1)]
	position = tilemap.map_to_local(spawnpoint)
	grid_pos = spawnpoint
	step_timer = STEP_COOLDOWN  # Allows immediate movement on first press


# --- Input Handling with Cooldown ---


# Use _physics_process for time-based movement, and pass delta
func _physics_process(delta: float):
	# 1. Update the cooldown timer
	step_timer -= delta

	# 2. Get the current direction the player is holding
	var input_direction = get_held_direction()

	# 3. Check conditions for initiating a move
	if input_direction != Vector2i.ZERO:
		# We only start a new move if the character is not already moving AND the cooldown is ready
		if not is_moving and step_timer <= 0.0:
			move_to_tile(input_direction)
			# Reset the cooldown timer immediately after starting the move
			step_timer = STEP_COOLDOWN


# Function to get the current input direction vector
func get_held_direction() -> Vector2i:
	var direction = Vector2i.ZERO

	if Input.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT
	elif Input.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif Input.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif Input.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN

	update_animation(direction)
	return direction


func update_animation(direction: Vector2i):
	if direction != Vector2i.ZERO:
		var walk_animation_name = ""
		match direction:
			Vector2i.UP:
				walk_animation_name = "walk_up"
			Vector2i.DOWN:
				walk_animation_name = "walk_down"
			Vector2i.RIGHT:
				walk_animation_name = "walk_right"
				sprite.flip_h = false
			Vector2i.LEFT:
				walk_animation_name = "walk_right"
				sprite.flip_h = true
			_:
				walk_animation_name = "walk_down"

		latest_direction = direction

		sprite.play(walk_animation_name)

	else:
		var idle_animation_name = ""
		match latest_direction:
			Vector2i.UP:
				idle_animation_name = "idle_up"
			Vector2i.DOWN:
				idle_animation_name = "idle_down"
			Vector2i.RIGHT:
				idle_animation_name = "idle_right"
				sprite.flip_h = false
			Vector2i.LEFT:
				idle_animation_name = "idle_right"
				sprite.flip_h = true
			_:
				idle_animation_name = "idle_down"

		# Play the determined idle animation
		sprite.play(idle_animation_name)


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

	tween = get_tree().create_tween()
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
func add_to_inventory(item_name: String, amount: int):
	inventory[item_name] = inventory.get(item_name, 0) + amount
	print("Inventory:", inventory)

func _on_area_2d_area_entered(area: Area2D):
	# Prüfen, ob das Objekt eine Funktion "collect" besitzt
	if area.has_method("collect"):
		area.collect(self)   # dem Item den Player übergen
