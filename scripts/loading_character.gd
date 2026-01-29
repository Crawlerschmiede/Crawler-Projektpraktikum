extends AnimatedSprite2D

# We use the ".." to look at the parent, then find the progress bar
@onready var progress_bar = $"../TextureProgressBar" 

@export var start_x: float = 0.0  # Where the character starts (left)
@export var end_x: float = 200.0    # Where the character ends (right)

var last_value: float = 0.0

# Add this variable at the top of your script
@export var follow_speed: float = 5.0 # Higher is faster, lower is slower/smoother

func _process(delta):
	if not progress_bar: return
	
	var current_value = progress_bar.value
	var target_ratio = current_value / 100.0
	
	# Calculate where the sprite SHOULD be based on the bar
	var target_x = lerp(start_x, end_x, target_ratio)
	
	# --- SMOOTH MOVEMENT ---
	# Instead of snapping, we move toward the target position slowly over time
	global_position.x = lerp(global_position.x, target_x, follow_speed * delta)
	
	# --- ANIMATION LOGIC ---
	# We check if the sprite is actually moving across the screen 
	# (checking position difference instead of bar value)
	if abs(global_position.x - target_x) > 0.5:
		if animation != "walk":
			play("walk")
		speed_scale = 0.8 # Slower walking animation
	else:
		if sprite_frames.has_animation("idle"):
			if animation != "idle":
				play("idle")
		else:
			stop()
		speed_scale = 1.0
