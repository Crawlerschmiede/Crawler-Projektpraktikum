extends CharacterBody2D
class_name LootBoxPickup

const ACCELERATION = 460.0
const MAX_SPEED = 225.0

@export var loot_table: Dictionary = {}

# Random Loot Settings
@export var random_min_weight = 10
@export var random_max_weight = 15

var player: Node2D = null
var being_picked_up = false
var data: Dictionary = {}  # JsonData.item_data


func _ready() -> void:
	# JsonData prüfen
	if JsonData == null or not ("item_data" in JsonData):
		push_error("JsonData.item_data fehlt! Lootbox wird entfernt.")
		queue_free()
		return

	data = JsonData.item_data

	#  Wenn loot_table leer ist -> automatisch generieren
	if loot_table == null or loot_table.is_empty():
		loot_table = _generate_random_loot(random_min_weight, random_max_weight)

	# Loot validieren / bereinigen
	loot_table = _clean_loot(loot_table)

	if loot_table.is_empty():
		push_warning("Lootbox hat kein gültiges Loot -> removed")
		queue_free()
		return

	add_to_group("Lootbox")


func _physics_process(delta: float) -> void:
	if being_picked_up and player != null and is_instance_valid(player):
		var dir = global_position.direction_to(player.global_position)
		velocity = velocity.move_toward(dir * MAX_SPEED, ACCELERATION * delta)

		if global_position.distance_to(player.global_position) < 20.0:
			_collect_loot()
			queue_free()

	move_and_slide()


func pick_up_item(body: Node2D) -> void:
	player = body
	being_picked_up = true


func _collect_loot() -> void:
	for item_name in loot_table.keys():
		PlayerInventory.add_item(item_name, int(loot_table[item_name]))

	#print("Lootbox collected:", loot_table)


# ============================================================
#  OPTIONAL: von außen Loot setzen (Boss Drop etc.)
# ============================================================


func set_loot(new_loot: Dictionary) -> void:
	loot_table = _clean_loot(new_loot)


func add_loot(item_name: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	if loot_table == null:
		loot_table = {}
	loot_table[item_name] = int(loot_table.get(item_name, 0)) + amount


# ============================================================
#  RANDOM LOOT GENERATOR (aus JSON loot_stats)
# ============================================================


func _generate_random_loot(min_weight: int, max_weight: int) -> Dictionary:
	var weight_limit = randi_range(min_weight, max_weight)

	# Kandidaten: Items die loot_stats haben
	var candidates: Array[String] = []
	for item_name in data.keys():
		var info = data[item_name]
		if typeof(info) != TYPE_DICTIONARY:
			continue
		if not info.has("loot_stats"):
			continue

		var ls = info["loot_stats"]
		if typeof(ls) != TYPE_DICTIONARY:
			continue

		# Muss mindestens weight haben
		if not ls.has("weight"):
			continue

		candidates.append(str(item_name))

	if candidates.is_empty():
		return {}

	var loot = {}
	var tries = 0

	while weight_limit > 0 and tries < 200:
		tries += 1

		var item = candidates.pick_random()
		var ls = data[item]["loot_stats"]

		var w = int(ls.get("weight", 1))
		if w <= 0:
			continue
		if w > weight_limit:
			continue

		var chance = float(ls.get("chance", 1.0))
		if chance < 1.0 and randf() > chance:
			continue

		var max_stack = int(ls.get("max_stack", 1))
		max_stack = max(1, max_stack)
		var amount = randi_range(1, max_stack)

		loot[item] = int(loot.get(item, 0)) + amount
		weight_limit -= w

	return loot


# ============================================================
#  Loot Bereinigung
# ============================================================


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
