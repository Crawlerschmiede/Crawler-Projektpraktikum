extends Label

@export var pulse_speed: float = 4.0  # How fast it flickers
@export var min_alpha: float = 0.5    # The darkest it gets
@export var max_alpha: float = 1.0    # The brightest it gets

func _process(_delta):
	var time = Time.get_ticks_msec() * 0.001
	
	# Combining two sine waves at different speeds creates "unpredictable" flickering
	var noise = sin(time * pulse_speed) * cos(time * pulse_speed * 1.5)
	
	var lerp_value = remap(noise, -1.0, 1.0, min_alpha, max_alpha)
	modulate = Color("773a0fff").lerp(Color("a68400ff"), lerp_value)
