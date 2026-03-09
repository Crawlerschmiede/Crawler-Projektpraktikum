class_name LootBoxPickup
extends CharacterBody2D

const ACCELERATION = 460.0
const MAX_SPEED = 225.0

@export var loot_table: Dictionary = {}

# Random Loot Settings
@export var random_min_weight = 10
@export var random_max_weight = 15

var player: Node2D = null
var being_picked_up = false
var data: Dictionary = {}

var collected := false  # <- neu: verhindert mehrfaches Einsammeln

@onready var animation_sprite = $AnimatedSprite2D


func _ready() -> void:
	if JsonData == null or not ("item_data" in JsonData):
		push_error("JsonData.item_data fehlt! Lootbox wird entfernt.")
		queue_free()
		return

	data = JsonData.item_data

	if loot_table == null or loot_table.is_empty():
		loot_table = _generate_random_loot(random_min_weight, random_max_weight)

	loot_table = _clean_loot(loot_table)

	if loot_table.is_empty():
		push_warning("Lootbox hat kein gültiges Loot -> removed")
		queue_free()
		return

	add_to_group("Lootbox")


func _physics_process(delta: float) -> void:
	if collected:
		return

	if being_picked_up and player != null and is_instance_valid(player):
		var dir = global_position.direction_to(player.global_position)
		velocity = velocity.move_toward(dir * MAX_SPEED, ACCELERATION * delta)

		if global_position.distance_to(player.global_position) < 20.0:
			_on_reached_player()
			return

	move_and_slide()


func pick_up_item(body: Node2D) -> void:
	if collected:
		return
	player = body
	being_picked_up = true


func _on_reached_player() -> void:
	if collected:
		return
	collected = true

	# Bewegung stoppen + nicht mehr anziehen
	being_picked_up = false
	velocity = Vector2.ZERO

	# Loot geben
	_collect_loot()

	# Öffnen-Animation (Name ggf. anpassen)
	if is_instance_valid(animation_sprite):
		if animation_sprite.sprite_frames and animation_sprite.sprite_frames.has_animation("open"):
			animation_sprite.play("open")
		else:
			# fallback falls es keine "open" gibt
			animation_sprite.play()

	# Erst nach 2 Sekunden löschen
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _collect_loot() -> void:
	pass # print("[LootBox] collecting loot:", loot_table)
	for item_name in loot_table.keys():
		pass # print("[LootBox] giving item:", item_name, loot_table[item_name])
		PlayerInventory.add_item(item_name, int(loot_table[item_name]))


func set_loot(new_loot: Dictionary) -> void:
	loot_table = _clean_loot(new_loot)


func add_loot(item_name: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	if loot_table == null:
		loot_table = {}
	loot_table[item_name] = int(loot_table.get(item_name, 0)) + amount


func _generate_random_loot(min_weight: int, max_weight: int) -> Dictionary:
	var weight_limit = GlobalRNG.randi_range(min_weight, max_weight)

	var candidates: Array[String] = []
	for item_name in data.keys():
		var info = data[item_name]
		if typeof(info) != TYPE_DICTIONARY:
			continue
		# skip level-specific variants that don't match current level
		if not _item_allowed_on_level(str(item_name)):
			pass # print("[LootBox] skip by level filter:", item_name)
			continue

		if not info.has("loot_stats"):
			continue

		var ls = _resolve_level_config(info["loot_stats"])
		if typeof(ls) != TYPE_DICTIONARY:
			continue
		if not ls.has("weight"):
			continue

		candidates.append(str(item_name))

	if candidates.is_empty():
		return {}

	var loot = {}
	var tries = 0

	while weight_limit > 0 and tries < 200:
		tries += 1
		var item = GlobalRNG.pick_random(candidates)
		var ls = _resolve_level_config(data[item]["loot_stats"])

		var w = int(ls.get("weight", 1))
		if w <= 0:
			continue
		if w > weight_limit:
			continue

		var chance = float(ls.get("chance", 1.0))
		if chance < 1.0 and GlobalRNG.randf() > chance:
			continue

		var max_stack = int(ls.get("max_stack", 1))
		max_stack = max(1, max_stack)
		var amount = GlobalRNG.randi_range(1, max_stack)

		loot[item] = int(loot.get(item, 0)) + amount
		weight_limit -= w

	return loot


func _resolve_level_config(conf: Variant) -> Variant:
	# If conf is not a dictionary, return as-is.
	if typeof(conf) != TYPE_DICTIONARY:
		return conf

	# Determine current world index from the active scene if possible,
	# fallback to root node name if active scene does not expose it.
	var lvl = 0
	var cs = get_tree().get_current_scene()
	if cs != null and "world_index" in cs:
		lvl = int(cs.world_index)
	else:
		var main_node = null
		if get_tree().root.has_node("MAIN Pet Dungeon"):
			main_node = get_tree().root.get_node("MAIN Pet Dungeon")
		if main_node != null and "world_index" in main_node:
			lvl = int(main_node.world_index)

	var key = str(lvl)
	if conf.has(key):
		return conf[key]

	# fallback: if conf already contains the expected keys, return it
	if conf.has("weight") or conf.has("chance") or conf.has("max_stack"):
		return conf

	# else try '0' or first numeric key
	if conf.has("0"):
		return conf["0"]

	for k in conf.keys():
		# return first dict entry as fallback
		if typeof(conf[k]) == TYPE_DICTIONARY:
			return conf[k]
	return conf


func _item_allowed_on_level(item_name: String) -> bool:
	# Items with suffix `_aN` are only allowed on level N. Others are global.
	var lvl = 0
	var cs = get_tree().get_current_scene()
	if cs != null and "world_index" in cs:
		lvl = int(cs.world_index)
	else:
		var main_node = null
		if get_tree().root.has_node("MAIN Pet Dungeon"):
			main_node = get_tree().root.get_node("MAIN Pet Dungeon")
		if main_node != null and "world_index" in main_node:
			lvl = int(main_node.world_index)

	var rex := RegEx.new()
	var err := rex.compile("_a(\\d+)$")
	if err != OK:
		pass # print("[LootBox] RegEx compile failed")
		return true
	var match := rex.search(item_name)
	if match == null:
		pass # print("[LootBox] item has no _aN suffix, allowed:", item_name, "lvl=", lvl)
		return true
	var parsed = int(match.get_string(1))
	# Mapping: asset suffix `_a1` corresponds to world_index 0 (offset -1)
	var ok = parsed == (lvl + 1)
	return ok


func _clean_loot(input: Dictionary) -> Dictionary:
	var cleaned = {}
	if input == null:
		return cleaned

	for item_name in input.keys():
		var amount = int(input[item_name])
		if amount <= 0:
			continue

		if not _item_exists(str(item_name)):
			push_warning("Lootbox: Item '%s' existiert nicht in JsonData -> skip" % str(item_name))
			continue

		cleaned[str(item_name)] = amount

	return cleaned


func _item_exists(nm: String) -> bool:
	return data.has(nm)
