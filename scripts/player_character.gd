class_name PlayerCharacter

extends MoveableEntity

# Time (in seconds) the character pauses on a tile before taking the next step
const STEP_COOLDOWN: float = 0.01
var step_timer: float = 0.01
var inventory := {}

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	if camera == null:
		print("Children:", get_children())
		push_error("❌ Camera2D fehlt im Player!")
		return

	camera.make_current()
	abilities_this_has = ["Punch", "Right Pivot", "Left Pivot", "Full Power Punch"]
	super_ready("pc")
	is_player = true
	setup(tilemap, 10, 1, 0)


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


func add_to_inventory(item_name: String, amount: int):
	inventory[item_name] = inventory.get(item_name, 0) + amount
	print("Inventory:", inventory)


func _on_area_2d_area_entered(area: Area2D):
	# Prüfen, ob das Objekt eine Funktion "collect" besitzt
	if area.has_method("collect"):
		area.collect(self)  # dem Item den Player übergen
