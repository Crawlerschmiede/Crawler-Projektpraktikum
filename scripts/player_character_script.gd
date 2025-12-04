extends CharacterBody2D

# The size of one tile in pixels
const TILE_SIZE: int = 16

# Flag to prevent movement while the character is currently moving (Tween is active)
var is_moving: bool = false 


# Time (in seconds) the character pauses on a tile before taking the next step
const STEP_COOLDOWN: float = 0.3
# The timer used to track when the next move is allowed
var step_timer: float = 0.1

# --- Setup ---

func _ready():
	# Make sure the character starts perfectly aligned to the grid
	global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	step_timer = STEP_COOLDOWN # Allows immediate movement on first press

# --- Input Handling with Cooldown ---

# Use _physics_process for time-based movement, and pass delta
func _physics_process(delta: float):
	# 1. Update the cooldown timer
	step_timer -= delta
	
	# 2. Get the current direction the player is holding
	var input_direction = get_held_direction()
	
	# 3. Check conditions for initiating a move
	if input_direction != Vector2.ZERO:
		# We only start a new move if the character is not already moving AND the cooldown is ready
		if not is_moving and step_timer <= 0.0:
			move_to_tile(input_direction)
			# Reset the cooldown timer immediately after starting the move
			step_timer = STEP_COOLDOWN

# Function to get the current input direction vector
func get_held_direction() -> Vector2:
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("move_right"):
		direction.x = 1
	if Input.is_action_pressed("move_left"):
		direction.x = -1
	if Input.is_action_pressed("move_down"):
		direction.y = 1
	if Input.is_action_pressed("move_up"):
		direction.y = -1
		
	return direction.normalized() # Normalize ensures consistent direction vector length

# --- Movement Logic ---

func move_to_tile(direction: Vector2):
	var target_position = global_position + (direction * TILE_SIZE)
	
	is_moving = true
	
	var tween = create_tween()
	# Duration (e.g., 0.15 seconds) should be less than STEP_COOLDOWN (0.2 seconds) 
	# to ensure the character stops completely before the cooldown finishes.
	tween.tween_property(self, "global_position", target_position, 0.15)
	
	tween.connect("finished", on_movement_finished)

func on_movement_finished():
	is_moving = false
	global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
