extends RefCounted
class_name GASearch

class Genome:
	var door_fill_chance: float
	var max_corridors: int
	var max_corridor_chain: int
	var corridor_bias: float

	func clone() -> Genome:
		var g := Genome.new()
		g.door_fill_chance = door_fill_chance
		g.max_corridors = max_corridors
		g.max_corridor_chain = max_corridor_chain
		g.corridor_bias = corridor_bias
		return g


class EvalResult:
	var genome: Genome
	var rooms_placed: int = 0
	var corridors_placed: int = 0
	var seed: int = 0


# --- GA Settings ---
var population_size := 40
var generations := 25
var total_evals := 50
var elite_keep := 4
var mutation_rate := 0.25
var crossover_rate := 0.70
var ga_seed := randi()


func search_best(
	generator: Node,
	room_lib: RoomLibrary,
	placer: RoomPlacer,
	start_room: PackedScene,
	max_rooms: int
) -> EvalResult:
	seed(ga_seed)

	# pop/gen fix
	var target := total_evals
	var pop = max(2, population_size)
	var gen = max(1, generations)
	if pop * gen != target:
		gen = int(ceil(float(target) / float(pop)))
		generations = gen
		print("⚠ [GA] pop*gen != total -> generations:", gen, "(evals=", pop * gen, ")")

	# init population
	var population: Array[Genome] = []
	for i in range(pop):
		population.append(_random_genome())

	var best_overall := EvalResult.new()
	best_overall.genome = _default_genome()
	best_overall.rooms_placed = -1
	best_overall.seed = ga_seed

	var eval_counter := 0

	for g_i in range(gen):
		var results: Array[EvalResult] = []

		for i in range(pop):
			if eval_counter >= target:
				break

			var trial_seed := ga_seed + eval_counter * 17 + g_i * 101
			var res := await _evaluate_genome(generator, room_lib, placer, start_room, max_rooms, population[i], trial_seed)
			results.append(res)
			eval_counter += 1

		results.sort_custom(func(a, b): return a.rooms_placed > b.rooms_placed)

		if results.size() > 0 and results[0].rooms_placed > best_overall.rooms_placed:
			best_overall = results[0]

		print("[GA] Gen", g_i, "| evals:", eval_counter, "/", target,
			"| best_this_gen:", results[0].rooms_placed,
			"| best_overall:", best_overall.rooms_placed)

		# selection pool (top half)
		var pool: Array[Genome] = []
		var half = max(2, int(results.size() / 2))
		for k in range(half):
			pool.append(results[k].genome)

		# elites
		var next_pop: Array[Genome] = []
		for e in range(min(elite_keep, results.size())):
			next_pop.append(results[e].genome.clone())

		# fill rest
		while next_pop.size() < pop:
			var child: Genome
			if randf() < crossover_rate and pool.size() >= 2:
				var p1 := pool[randi() % pool.size()]
				var p2 := pool[randi() % pool.size()]
				child = _crossover(p1, p2)
			else:
				child = pool[randi() % pool.size()].clone()

			if randf() < mutation_rate:
				_mutate(child)

			next_pop.append(child)

		population = next_pop

		if eval_counter >= target:
			break

	return best_overall


func _evaluate_genome(
	generator: Node,
	room_lib: RoomLibrary,
	placer: RoomPlacer,
	start_room: PackedScene,
	max_rooms: int,
	genome: Genome,
	trial_seed: int
) -> EvalResult:
	var container := Node2D.new()
	container.name = "_GA_CONTAINER_"
	generator.add_child(container)

	var stats = await placer.generate_stats(container, room_lib, start_room, max_rooms, genome, trial_seed)

	container.queue_free()

	var res := EvalResult.new()
	res.genome = genome
	res.rooms_placed = stats.rooms
	res.corridors_placed = stats.corridors
	res.seed = trial_seed
	return res


func _default_genome() -> Genome:
	var g := Genome.new()
	g.door_fill_chance = 1.0
	g.max_corridors = 10
	g.max_corridor_chain = 3
	g.corridor_bias = 1.0
	return g


func _random_genome() -> Genome:
	var g := _default_genome()
	g.door_fill_chance = clamp(randf_range(0.60, 1.0), 0.0, 1.0)
	g.max_corridors = int(clamp(randi_range(0, 25), 0, 40))
	g.max_corridor_chain = int(clamp(randi_range(1, 4), 1, 6))
	g.corridor_bias = clamp(randf_range(0.6, 1.6), 0.1, 3.0)
	return g


func _crossover(a: Genome, b: Genome) -> Genome:
	var c := a.clone()
	if randf() < 0.5: c.door_fill_chance = b.door_fill_chance
	if randf() < 0.5: c.max_corridors = b.max_corridors
	if randf() < 0.5: c.max_corridor_chain = b.max_corridor_chain
	if randf() < 0.5: c.corridor_bias = b.corridor_bias
	return c


func _mutate(g: Genome) -> void:
	if randf() < 0.5:
		g.door_fill_chance = clamp(g.door_fill_chance + randf_range(-0.12, 0.12), 0.2, 1.0)
	if randf() < 0.5:
		g.max_corridors = int(clamp(g.max_corridors + randi_range(-4, 6), 0, 40))
	if randf() < 0.5:
		g.max_corridor_chain = int(clamp(g.max_corridor_chain + randi_range(-1, 1), 1, 6))
	if randf() < 0.5:
		g.corridor_bias = clamp(g.corridor_bias + randf_range(-0.25, 0.25), 0.3, 2.5)
