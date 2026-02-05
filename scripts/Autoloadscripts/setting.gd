extends Node


func _ready():
	# initialize deterministic global RNG through GlobalRNG autoload
	GlobalRNG.seed_base(42)
