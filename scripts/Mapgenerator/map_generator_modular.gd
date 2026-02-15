extends Node2D

signal generation_progress(p: float, text: String)

const MGGENOME = preload("res://scripts/Mapgenerator/helpers/mg_genome.gd")
const MGCOLL = preload("res://scripts/Mapgenerator/helpers/mg_collision.gd")
const MGIO = preload("res://scripts/Mapgenerator/helpers/mg_io.gd")
const MGGA = preload("res://scripts/Mapgenerator/helpers/mg_ga.gd")
const MGGEN = preload("res://scripts/Mapgenerator/helpers/mg_generation.gd")
const MGBake = preload("res://scripts/Mapgenerator/helpers/mg_bake.gd")

# --- Exports (copied from original) ---
@export var closed_doors_folder: String = "res://scenes/rooms/Closed Doors/"
@export var rooms_folder: String = "res://scenes/rooms/Rooms/"
@export var start_room: PackedScene
@export var boss_room: PackedScene
@export var max_rooms: int = 10

@export var player_scene: PackedScene

# Basis-Regeln
@export var base_max_corridors: int = 10
@export var base_max_corridor_chain: int = 3
@export_range(0.0, 1.0, 0.01) var base_door_fill_chance: float = 1.0

# GA
@export var ga_total_evals: int = 25
@export var ga_generations: int = 25
@export var ga_population_size: int = ga_generations * ga_total_evals
@export var ga_elite_keep: int = 4
@export var ga_mutation_rate: float = 0.25
@export var ga_crossover_rate: float = 0.70
@export var ga_seed: int = 42
@export var build_best_map_after_ga: bool = true
@export var yield_frame_chunk: int = 100

# Runtime instances of modules
var mg_genome = null
var mg_coll = null
var mg_io = null
var mg_ga = null
var mg_gen = null
var mg_bake = null

# --- Public state ---
var closed_door_scenes: Array = []
var room_scenes: Array = []
var player
var world_tilemap: TileMapLayer
var world_tilemap_top: TileMapLayer
var minimap: TileMapLayer
var room_type_counts: Dictionary = {}
var placed_rooms: Array = []
var corridor_count: int = 0
var boss_room_spawned := false
var room_id: int = 0

#---- Save Game ----
var last_best_seed: int = 0
var last_best_genome = null
var current_floor_index: int = 0 

# Private
var _closed_door_cache: Dictionary = {}
var _corridor_cache: Dictionary = {}
var _rng := GlobalRNG.get_rng()
var _yield_counter := 0


func _ready() -> void:
	mg_genome = MGGENOME.new()
	mg_coll = MGCOLL.new()
	mg_io = MGIO.new()
	mg_ga = MGGA.new()
	mg_gen = MGGEN.new()
	mg_bake = MGBake.new()


func _emit_progress_mapped(start: float, end: float, local_p: float, text: String) -> void:
	var lp = clamp(local_p, 0.0, 1.0)
	var p = clamp(start + (end - start) * lp, 0.0, 1.0)
	generation_progress.emit(p, text)


func _yield_if_needed(step: int = 200) -> void:
	_yield_counter += 1
	if _yield_counter % step == 0:
		await get_tree().process_frame


# --- Delegating API ---
func load_room_scenes_from_folder(path: String) -> Array:
	return mg_io.load_room_scenes_from_folder(path)


func load_closed_door_scenes_from_folder(path: String) -> Array:
	return mg_io.load_closed_door_scenes_from_folder(path)


func get_closed_door_for_direction(dir: String) -> PackedScene:
	dir = dir.to_lower()
	var candidates: Array = []
	for s in closed_door_scenes:
		if mg_io._get_closed_door_direction(s) == dir:
			candidates.append(s)
	if candidates.is_empty():
		return null
	return GlobalRNG.pick_random(candidates)


func genetic_search_best():
	return await mg_ga.genetic_search_best(self)


func generate_with_genome(genome, trial_seed: int, verbose: bool, parent_override: Node = null):
	return await mg_gen.generate_with_genome(self, genome, trial_seed, verbose, parent_override)


func bake_rooms_into_world_tilemap() -> void:
	await mg_bake.bake_rooms_into_world_tilemap(self)
	return


func clear_children_rooms_only() -> void:
	mg_io.clear_children_rooms_only(self)


func clear_world_tilemaps() -> void:
	mg_io.clear_world_tilemaps(self)


func get_main_tilemap() -> TileMapLayer:
	return mg_io.get_main_tilemap(self)


func get_random_tilemap() -> Dictionary:
	_yield_counter = 0
	_emit_progress_mapped(0.0, 0.05, 0.0, "Preparing scenes...")
	await get_tree().process_frame

	# load/start scenes
	start_room = load("res://scenes/rooms/Rooms/room_11x11_4.tscn")
	room_scenes = load_room_scenes_from_folder(rooms_folder)
	closed_door_scenes = load_closed_door_scenes_from_folder(closed_doors_folder)

	_emit_progress_mapped(0.05, 0.45, 0.0, "Running GA...")
	var best = await genetic_search_best()
	last_best_seed = best.seed
	last_best_genome = best.genome

	_emit_progress_mapped(0.05, 0.45, 1.0, "GA finished")
	await get_tree().process_frame

	minimap = TileMapLayer.new()
	minimap.name = "Minimap"
	minimap.visibility_layer = 1 << 1

	if build_best_map_after_ga:
		clear_world_tilemaps()
		clear_children_rooms_only()
		await generate_with_genome(best.genome, best.seed, true)
		await bake_rooms_into_world_tilemap()
		for r in placed_rooms:
			r.visible = false
		

	return {"floor": world_tilemap, "top": world_tilemap_top, "minimap": minimap}

#---- Save Game Funktionen zum Speichern und Laden 
func export_map_blueprint() -> Dictionary:
	return {
		"seed": last_best_seed,
		"genome": last_best_genome.to_dict()
	}
	
func build_map_from_blueprint(bp: Dictionary) -> Dictionary:
	_yield_counter = 0
	_emit_progress_mapped(0.0, 0.05, 0.0, "Preparing scenes...")
	await get_tree().process_frame

	start_room = load("res://scenes/rooms/Rooms/room_11x11_4.tscn")
	room_scenes = load_room_scenes_from_folder(rooms_folder)
	closed_door_scenes = load_closed_door_scenes_from_folder(closed_doors_folder)

	var seed: int = int(bp.get("seed", ga_seed))
	var genome_dict: Dictionary = bp.get("genome", {})
	var genome: MGGENOME.Genome = MGGENOME.Genome.from_dict(genome_dict)

	clear_world_tilemaps()
	clear_children_rooms_only()

	placed_rooms.clear()
	corridor_count = 0
	boss_room_spawned = false
	room_id = 0
	room_type_counts.clear()

	_emit_progress_mapped(0.05, 0.45, 0.0, "Building map from save...")
	await generate_with_genome(genome, seed, true)
	_emit_progress_mapped(0.05, 0.45, 1.0, "Map build finished")

	_emit_progress_mapped(0.45, 0.95, 0.0, "Baking tilemaps...")
	await bake_rooms_into_world_tilemap()
	_emit_progress_mapped(0.45, 0.95, 1.0, "Baking done")

	for r in placed_rooms:
		r.visible = false

	minimap = TileMapLayer.new()
	minimap.name = "Minimap"
	minimap.visibility_layer = 1 << 1

	_emit_progress_mapped(0.95, 1.0, 1.0, "Loaded from save")
	await get_tree().process_frame

	return {"floor": world_tilemap, "top": world_tilemap_top, "minimap": minimap}
