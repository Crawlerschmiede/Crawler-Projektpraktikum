# GA-Orchestrator (delegiert an generate_with_genome)

class_name MGGA

const MGGENOME = preload("res://scripts/Mapgenerator/helpers/mg_genome.gd")
const MGGEN = preload("res://scripts/Mapgenerator/helpers/mg_generation.gd")

# instances
var mg_genome = MGGENOME.new()
var mg_gen = MGGEN.new()


func genetic_search_best(gen):
	if gen.room_scenes.is_empty() or gen.start_room == null:
		push_error("❌ [GA] room_scenes leer oder start_room NULL")
		var dummy = mg_genome.EvalResult.new()
		dummy.genome = mg_genome.make_default_genome(
			gen.base_door_fill_chance, gen.base_max_corridors, gen.base_max_corridor_chain
		)
		return dummy

	gen.ga_population_size = max(2, gen.ga_population_size)
	gen.ga_generations = max(1, gen.ga_generations)
	gen.ga_total_evals = max(1, gen.ga_total_evals)

	var target = gen.ga_total_evals
	var pop = gen.ga_population_size
	var gcount = gen.ga_generations
	if pop * gcount != target:
		gcount = int(ceil(float(target) / float(pop)))
		gen.ga_generations = gcount

	var population: Array = []
	for i in range(pop):
		population.append(mg_genome.random_genome(gen._rng))

	var best_overall = mg_genome.EvalResult.new()
	best_overall.genome = mg_genome.make_default_genome(
		gen.base_door_fill_chance, gen.base_max_corridors, gen.base_max_corridor_chain
	)
	best_overall.rooms_placed = -1

	var eval_counter = 0
	for g_i in range(gcount):
		var results: Array = []
		for i in range(pop):
			if eval_counter >= target:
				break
			var trial_seed = gen.ga_seed + eval_counter * 17 + g_i * 101
			var res = await evaluate_genome(gen, population[i], trial_seed)
			results.append(res)
			eval_counter += 1
			gen._emit_progress_mapped(
				0.05,
				0.45,
				clamp(float(eval_counter) / float(target), 0.0, 1.0),
				"GA eval %d/%d" % [eval_counter, target]
			)
			await gen.get_tree().process_frame

		results.sort_custom(func(a, b) -> bool: return a.rooms_placed > b.rooms_placed)

		if results.size() > 0 and results[0].rooms_placed > best_overall.rooms_placed:
			best_overall = results[0]

		var pool: Array = []
		var half: int = max(2, int(results.size() / 2))
		for k in range(half):
			pool.append(results[k].genome)

		var next_pop: Array = []
		for e in range(min(gen.ga_elite_keep, results.size())):
			next_pop.append(results[e].genome.clone())

		while next_pop.size() < pop:
			var child
			if gen._rng.randf() < gen.ga_crossover_rate and pool.size() >= 2:
				var p1 = pool[gen._rng.randi_range(0, pool.size() - 1)]
				var p2 = pool[gen._rng.randi_range(0, pool.size() - 1)]
				child = mg_genome.crossover(p1, p2, gen._rng)
			else:
				child = pool[gen._rng.randi_range(0, pool.size() - 1)].clone()

			if gen._rng.randf() < gen.ga_mutation_rate:
				mg_genome.mutate(child, gen._rng)

			next_pop.append(child)

		population = next_pop

		var progress = float(eval_counter) / float(target)
		gen._emit_progress_mapped(0.05, 0.45, clamp(progress, 0.0, 1.0), "GA gen %d" % g_i)
		await gen.get_tree().process_frame

		if eval_counter >= target:
			break

	return best_overall


func evaluate_genome(gen, genome, trial_seed: int):
	var container = Node2D.new()
	container.name = "_GA_CONTAINER_"
	gen.add_child(container)

	var prev_seed = 0
	if Engine.has_singleton("SettingsManager"):
		var settings_manager = Engine.get_singleton("SettingsManager")
		if settings_manager.has_method("get_game_seed"):
			prev_seed = settings_manager.get_game_seed()
		if settings_manager.has_method("set_game_seed"):
			settings_manager.set_game_seed(trial_seed)

	var stats = await mg_gen.generate_with_genome(gen, genome, trial_seed, false, container)

	if Engine.has_singleton("SettingsManager"):
		var settings_manager_reset = Engine.get_singleton("SettingsManager")
		if settings_manager_reset.has_method("set_game_seed"):
			settings_manager_reset.set_game_seed(prev_seed)

	container.queue_free()

	var res = mg_genome.EvalResult.new()
	res.genome = genome
	res.rooms_placed = stats.rooms
	res.corridors_placed = stats.corridors
	res.seed = trial_seed
	return res
