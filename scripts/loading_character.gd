extends AnimatedSprite2D

# We use the ".." to look at the parent, then find the progress bar
@onready var progress_bar = $"../TextureProgressBar" 

@export var start_x: float = 0.0  # Where the character starts (left)
@export var end_x: float = 640.0    # Where the character ends (right)

var last_value: float = 0.0

func _process(_delta):
	var current_value = progress_bar.value
	var ratio = current_value / progress_bar.max_value
	speed_scale = 1.5 if current_value > last_value else 1.0
	# Update Position
	global_position.x = lerp(start_x, end_x, ratio)
	
	# --- ANIMATION LOGIC ---
	if current_value > last_value:
		# The bar is moving, so play the walk animation
		if animation != "walk":
			play("walk")
	else:
		# The bar stopped (or finished), so play idle or stop
		if sprite_frames.has_animation("idle"):
			play("idle")
		else:
			stop() # Freezes on the current frame
			
	last_value = current_value
