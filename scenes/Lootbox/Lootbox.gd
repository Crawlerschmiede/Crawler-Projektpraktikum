extends CharacterBody2D
class_name LootBoxPickup

const ACCELERATION: float = 460.0
const MAX_SPEED: float = 225.0

@export var loot_table: Dictionary = {
	"Hund": 500
}
# Beispiel:
# {
#   "Gold": 10,
#   "Potion": 2,
#   "Hund": 1
# }

var player: Node2D = null
var being_picked_up: bool = false
var data: Dictionary = {} # JsonData.item_data


func _ready() -> void:
	# JsonData prüfen
	if JsonData == null or not ("item_data" in JsonData):
		push_error("JsonData.item_data fehlt! Lootbox wird entfernt.")
		queue_free()
		return

	data = JsonData.item_data

	# Loot validieren
	if loot_table == null or loot_table.is_empty():
		push_warning("Lootbox hat keinen loot_table -> wird entfernt.")
		queue_free()
		return

	# Nur gültige Items behalten
	var cleaned := {}
	for item_name in loot_table.keys():
		var amount := int(loot_table[item_name])
		if amount <= 0:
			continue

		if not _item_exists(item_name):
			push_warning("Lootbox: Item '%s' existiert nicht in JsonData.item_data -> skip" % item_name)
			continue

		cleaned[item_name] = amount

	loot_table = cleaned

	if loot_table.is_empty():
		push_warning("Lootbox: alle Loot Items ungültig -> removed")
		queue_free()
		return

	# Gruppe setzen (Lootbox selbst)
	add_to_group("Lootbox")


func _physics_process(delta: float) -> void:
	if being_picked_up and player != null and is_instance_valid(player):
		var direction: Vector2 = global_position.direction_to(player.global_position)
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)

		if global_position.distance_to(player.global_position) < 20.0:
			_collect_loot()
			queue_free()

	move_and_slide()


func pick_up_item(body: Node2D) -> void:
	player = body
	being_picked_up = true


func _collect_loot() -> void:
	for item_name in loot_table.keys():
		var amount := int(loot_table[item_name])
		PlayerInventory.add_item(item_name, amount)

	print("Lootbox collected:", loot_table)


func set_loot(new_loot: Dictionary) -> void:
	loot_table = new_loot


func add_loot(item_name: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	if loot_table == null:
		loot_table = {}
	loot_table[item_name] = int(loot_table.get(item_name, 0)) + amount


func _item_exists(nm: String) -> bool:
	return data.has(nm)
