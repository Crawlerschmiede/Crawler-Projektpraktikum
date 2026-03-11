extends RefCounted

const MAX_SPAWN_SELECTION_ITERATIONS := 100
var _enemy_scene: PackedScene = null


func configure(enemy_scene: PackedScene) -> void:
	_enemy_scene = enemy_scene


func spawn_enemies(
	do_boss: bool,
	world_index: int,
	data: Dictionary,
	dungeon_floor: TileMapLayer,
	dungeon_top: TileMapLayer,
	world_root: Node,
	fallback_parent: Node
) -> void:
	if data == null or data.is_empty():
		push_warning("EnemySpawnFlow.spawn_enemies: entity data is empty")
		return

	var settings: Dictionary = data.get("_settings", {})
	var max_weights = settings.get("max_total_weight_per_level", [])
	var max_weight: int = settings.get("default_max_total_weight", 30)

	if world_index < max_weights.size():
		max_weight = max_weights[world_index]

	var defs: Array[Dictionary] = []

	for k in data.keys():
		if str(k).begins_with("_"):
			continue

		var d: Dictionary = data[k]
		if d.get("entityCategory") != "enemy" and not do_boss:
			continue
		elif d.get("entityCategory") != "boss" and do_boss:
			continue

		var is_tutorial_enemy = "tutorial" in d.get("behaviour", [])
		var is_tutorial_world = world_index == -1

		if is_tutorial_world and not is_tutorial_enemy:
			continue
		elif not is_tutorial_world and is_tutorial_enemy:
			continue

		if d.has("alias_of"):
			var base = data[d["alias_of"]]
			var merged = base.duplicate(true)
			for x in d.keys():
				merged[x] = d[x]
			d = merged

		d["_id"] = str(k)
		defs.append(d)

	if defs.is_empty():
		if do_boss:
			push_warning("spawn_enemies: no boss definitions available for world %d" % world_index)
		else:
			push_warning("spawn_enemies: no enemy definitions available for world %d" % world_index)
		return

	var weights: Array[float] = []
	var total = 0.0

	for d in defs:
		var sr_raw = d.get("spawnrate", {})
		var sr = {}
		if sr_raw.has(str(world_index)):
			sr = sr_raw[str(world_index)]
		elif sr_raw.has("min"):
			sr = sr_raw

		var avg := (float(sr.get("min", 0)) + float(sr.get("max", 0))) * 0.5
		weights.append(avg)
		total += avg

	if total <= 0:
		for i in range(weights.size()):
			weights[i] = 1.0
		total = float(weights.size())

	var rng := GlobalRNG.get_rng()
	var current_weight = 0
	var spawn_plan = {}

	var roll: float
	var acc: float
	var chosen: int

	# Debug: print available defs and weights
	var def_ids := []
	for d in defs:
		def_ids.append(d.get("_id", "?"))
	print("[EnemySpawnFlow] defs:", def_ids)
	print("[EnemySpawnFlow] weights:", weights)
	print("[EnemySpawnFlow] total weight:", total)

	if do_boss:
		print("Should spawn boss")
		roll = rng.randf() * total
		print("[EnemySpawnFlow] boss roll:", roll)
		acc = 0.0
		chosen = 0
		for j in range(defs.size()):
			acc += weights[j]
			if roll <= acc:
				chosen = j
				break
		var def = defs[chosen]
		spawn_enemy(
			def.get("sprite_type", "what"),
			def.get("behaviour", []),
			def.get("skills", []),
			def.get("stats", {}),
			def.get("weight", 1),
			dungeon_floor,
			dungeon_top,
			world_root,
			fallback_parent,
			true
		)
		print("Spawned boss!")
		return

	for _i in range(MAX_SPAWN_SELECTION_ITERATIONS):
		if current_weight >= max_weight:
			break

		roll = rng.randf() * total
		print("[EnemySpawnFlow] roll:", roll)
		acc = 0.0
		chosen = 0

		for j in range(defs.size()):
			acc += weights[j]
			if roll <= acc:
				chosen = j
				break

		var def = defs[chosen]

		var sc_raw = def.get("spawncount", {})
		var sc = {}
		if sc_raw.has(str(world_index)):
			sc = sc_raw[str(world_index)]
		elif sc_raw.has("min"):
			sc = sc_raw

		var count := rng.randi_range(int(sc.get("min", 0)), int(sc.get("max", 1)))
		var w = int(def.get("weight", 1))
		var id = def["_id"]

		for _j in range(count):
			if current_weight + w > max_weight:
				break

			spawn_plan[id] = spawn_plan.get(id, 0) + 1
			current_weight += w

	for id in spawn_plan.keys():
		var def = data[id]
		if def.has("alias_of"):
			def = data[def["alias_of"]]

		for i in range(spawn_plan[id]):
			spawn_enemy(
				def.get("sprite_type", id),
				def.get("behaviour", []),
				def.get("skills", []),
				def.get("stats", {}),
				def.get("weight", 1),
				dungeon_floor,
				dungeon_top,
				world_root,
				fallback_parent
			)
			print("spawn: ", def.get("sprite_type", id))


func spawn_enemy(
	sprite_type: String,
	behaviour: Array,
	skills: Array,
	stats: Dictionary,
	xp: int,
	dungeon_floor: TileMapLayer,
	dungeon_top: TileMapLayer,
	world_root: Node,
	fallback_parent: Node,
	boss: bool = false
) -> void:
	if _enemy_scene == null:
		push_warning("EnemySpawnFlow.spawn_enemy: enemy scene is not configured")
		return

	var e = _enemy_scene.instantiate()
	e.add_to_group("enemy")
	e.add_to_group("vision_objects")

	e.types = behaviour
	e.sprite_type = sprite_type
	e.abilities_this_has = skills
	e.boss = boss
	e.xp = xp
	var hp = stats.get("hp", 1)
	var strv = stats.get("str", 1)
	var defv = stats.get("def", 1)

	e.setup(dungeon_floor, dungeon_top, hp, strv, defv, stats)

	if world_root != null:
		world_root.add_child(e)
	elif fallback_parent != null:
		fallback_parent.add_child(e)
