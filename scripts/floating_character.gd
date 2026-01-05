extends Sprite2D

@export var horizontal: bool = true # Toggle this in the Inspector!
@export var min_speed: float = 50.0
@export var max_speed: float = 100.0
@export var rotation_speed: float = 0.5
@export var float_amplitude: float = 17.0

var current_speed: float = 0.0
var time: float = 0.0
var anchor_pos: float = 0.0 # This replaces start_y for more flexibility
var screen_size: Vector2
var sprite_dim: float = 0.0

func _ready():
	screen_size = get_viewport_rect().size
	
	# Determine if we use width or height for the "off-screen" calculation
	if texture:
		sprite_dim = (texture.get_width() if horizontal else texture.get_height()) * scale.x / 2
	
	_reset_character(true)

func _process(delta):
	time += delta
	rotation += rotation_speed * delta
	
	if horizontal:
		# --- Horizontal Movement ---
		position.x += current_speed * delta
		position.y = anchor_pos + (sin(time) * float_amplitude)
		
		if (current_speed > 0 and position.x > screen_size.x + sprite_dim) or \
		   (current_speed < 0 and position.x < -sprite_dim):
			_reset_character(false)
	else:
		# --- Vertical Movement ---
		position.y += current_speed * delta
		position.x = anchor_pos + (sin(time) * float_amplitude)
		
		if (current_speed > 0 and position.y > screen_size.y + sprite_dim) or \
		   (current_speed < 0 and position.y < -sprite_dim):
			_reset_character(false)

func _reset_character(first_spawn: bool):
	current_speed = randf_range(min_speed, max_speed)
	if randf() > 0.5: current_speed *= -1
	time = randf() * 10.0
	
	if horizontal:
		anchor_pos = randf_range(50, screen_size.y - 50)
		if first_spawn:
			position.x = randf_range(0, screen_size.x)
		else:
			position.x = -sprite_dim if current_speed > 0 else screen_size.x + sprite_dim
	else:
		# For Vertical, the "anchor" is the X position
		anchor_pos = randf_range(50, screen_size.x - 50)
		if first_spawn:
			position.y = randf_range(0, screen_size.y)
		else:
			position.y = -sprite_dim if current_speed > 0 else screen_size.y + sprite_dim
