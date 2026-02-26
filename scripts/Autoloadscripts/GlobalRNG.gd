extends Node

var rng: RandomNumberGenerator
var base_seed: int = 40
var _counter: int = 0


func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = int(base_seed)


func seed_base(s: int) -> void:
	base_seed = int(s)
	_counter = 0
	_ensure_rng()
	rng.seed = int(base_seed)


func next_seed() -> int:
	_counter += 1
	return int(base_seed + _counter)


func get_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = next_seed()
	return r


func randf() -> float:
	_ensure_rng()
	return rng.randf()


func randi() -> int:
	_ensure_rng()
	return rng.randi()


func randi_range(min_v: int, max_v: int) -> int:
	_ensure_rng()
	return rng.randi_range(min_v, max_v)


func rand_range(a: float, b: float) -> float:
	_ensure_rng()
	return rng.rand_range(a, b)


func randf_range(a: float, b: float) -> float:
	_ensure_rng()
	return rng.randf_range(a, b)


func shuffle_array(arr: Array, r: RandomNumberGenerator = null) -> void:
	# In-place Fisher-Yates shuffle using provided RNG (or internal rng)
	var rr: RandomNumberGenerator = r if r != null else null
	if rr == null:
		_ensure_rng()
		rr = rng
	var n := arr.size()
	for i in range(n - 1, 0, -1):
		var j := rr.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func pick_random(arr: Array, r: RandomNumberGenerator = null):
	if arr == null or arr.is_empty():
		return null
	var rr: RandomNumberGenerator = r if r != null else null
	if rr == null:
		_ensure_rng()
		rr = rng
	var idx := rr.randi_range(0, arr.size() - 1)
	return arr[idx]


func _ensure_rng() -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = int(base_seed)


func reset() -> void:
	# Reset counter and reseed internal RNG
	_counter = 0
	_ensure_rng()
	rng.seed = int(base_seed)
