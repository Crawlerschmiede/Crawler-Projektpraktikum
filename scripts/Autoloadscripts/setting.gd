extends Node


func _ready():
	# initialize deterministic global RNG through GlobalRNG autoload
	GlobalRNG.seed_base(42)


func reset() -> void:
	# Re-seed deterministic RNG to the startup value
	GlobalRNG.seed_base(42)
