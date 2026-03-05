extends PointLight2D

@export var flicker_speed: float = 4.0
@export var noise_strength: float = 0.4
@export var base_energy: float = 2.0
@export var base_scale: float = 1.0

var noise = FastNoiseLite.new()
var time_passed: float = 0.0


func _ready():
	noise.seed = randi()
	noise.frequency = 0.25

	color = Color("ffd2b3")


func _process(delta):
	time_passed += delta * flicker_speed

	var noise_val = noise.get_noise_1d(time_passed)

	energy = base_energy * (1.0 - (noise_val * noise_strength))

	texture_scale = base_scale + (noise_val * (noise_strength * 0.1))
