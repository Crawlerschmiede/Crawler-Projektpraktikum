extends Node2D
class_name MerchantEntity

signal merchant_updated(data: Dictionary)
signal player_entered_merchant(entity: Node, data: Dictionary)
signal player_left_merchant(entity: Node)

@export var seed := 0
@export var min_total_weight := 10
@export var max_total_weight := 15

var merchant_items: Array = []  
# [{name, count, price}]


func _ready():
	_generate_merchant_data()
	print("merchant_items:", merchant_items)
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	print("BODY:", body)

	if body.is_in_group("player"):
		print("PLAYER DETECTED")
		emit_signal("player_entered_merchant", self, _get_data())


func _on_body_exited(body):
	if body == null:
		return
	print("BODY EXIT:", body)
	if body.is_in_group("player"):
		print("PLAYER LEFT MERCHANT")
		emit_signal("player_left_merchant", self)


# --------------------
# DATA ACCESS
# --------------------
func _get_data() -> Dictionary:
	return { "items": merchant_items }


# --------------------
# BUY FROM UI
# --------------------
func buy_item(index: int) -> void:

	if index < 0 or index >= merchant_items.size():
		return

	var item = merchant_items[index]

	if item["count"] <= 0:
		return

	# try pay
	if not PlayerInventory.spend_coins(item["price"]):
		return

	# give player
	PlayerInventory.add_item(item["name"], 1)

	# reduce stock
	item["count"] -= 1
	merchant_items[index] = item

	emit_signal("merchant_updated", _get_data())

func _generate_merchant_data() -> void:

	if JsonData == null or not ("item_data" in JsonData):
		push_error("JsonData.item_data missing!")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()

	var items: Dictionary = JsonData.item_data
	var keys := items.keys()
	keys.shuffle()

	var target_weight := rng.randi_range(min_total_weight, max_total_weight)
	var current_weight := 0

	for item_key in keys:

		if current_weight >= target_weight:
			break

		var data: Dictionary = items[item_key]
		if not data.has("merchant"):
			continue

		var m = data.merchant

		# chance
		if m.has("chance") and rng.randf() > float(m.chance):
			continue

		# weight
		var item_weight := int(m.get("weight", 1))
		if current_weight + item_weight > target_weight:
			continue

		# count
		var count := rng.randi_range(
			int(m.get("min_count", 1)),
			int(m.get("max_count", 1))
		)

		# price
		var price := rng.randi_range(
			int(m.get("min_price", 1)),
			int(m.get("max_price", 1))
		)

		merchant_items.append({
			"name": item_key,
			"count": count,
			"price": price
		})

		current_weight += item_weight
