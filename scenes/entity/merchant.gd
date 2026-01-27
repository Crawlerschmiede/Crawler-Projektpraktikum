extends CharacterBody2D
class_name MerchantEntity

signal merchant_updated
signal player_entered_merchant
signal player_left_merchant

@export var seed := 0
@export var min_total_weight := 20
@export var max_total_weight := 30
@export var merchant_id: String = ""
@export var sell_batch: int = 2
@export var merchant_room: String = ""

var merchant_items: Array = []  
# [{name, count, price}]


func _get_registry_key() -> String:
	# ensure a merchant id (can be set in editor); fallback based on position
	if merchant_id == "":
		merchant_id = "merchant_%d_%d" % [int(global_position.x), int(global_position.y)]

	# decide registry key: use exported merchant_room if set, otherwise current scene name
	if merchant_room != "":
		return "%s_%s" % [merchant_room, merchant_id]

	var scene_name := "global"
	var cs = null
	if get_tree().has_method("get_current_scene"):
		cs = get_tree().get_current_scene()
	if cs != null:
		scene_name = str(cs.name)

	return "%s_%s" % [scene_name, merchant_id]


func _ready():
	var reg_key := _get_registry_key()
	if typeof(MerchantRegistry) != TYPE_NIL and MerchantRegistry != null and MerchantRegistry.has(reg_key):
		merchant_items = MerchantRegistry.get_items(reg_key)
		# ensure each item has a buy_amount field (default to sell_batch)
		for i in range(merchant_items.size()):
			var it = merchant_items[i]
			if typeof(it) == TYPE_DICTIONARY:
				it["buy_amount"] = int(it.get("buy_amount", sell_batch))
				merchant_items[i] = it
	else:
		_generate_merchant_data()
		if typeof(MerchantRegistry) != TYPE_NIL and MerchantRegistry != null:
			MerchantRegistry.set_items(reg_key, merchant_items)

	print("merchant_items:", merchant_items)
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	if body.is_in_group("player"):

		var rk := _get_registry_key()
		if MerchantRegistry != null:
			merchant_items = MerchantRegistry.get_items(rk)

		print("Merchant items on enter:", merchant_items)
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
func buy_item(index: int, amount: int = -1) -> bool:
	# amount <=0 -> use sell_batch
	if amount <= 0:
		amount = sell_batch

	if index < 0 or index >= merchant_items.size():
		return false

	var item = merchant_items[index]
	if item["buy_amount"] <= 0:
		return false

	# allow per-item override for buy amount (e.g. item defines "buy_amount")
	var per_item_amount := int(item.get("buy_amount", sell_batch))
	var to_buy := amount if amount > 0 else per_item_amount

	# clamp to available stock
	to_buy = min(to_buy, int(item["count"]))
	if to_buy <= 0:
		return false

	var total_price = int(item["price"]) * to_buy

	# try pay; only proceed when payment succeeds
	if not PlayerInventory.spend_coins(total_price):
		# payment failed
		return false

	# give player
	PlayerInventory.add_item(item["name"], to_buy)

	# reduce stock and update merchant_items
	item["buy_amount"] -= 1
	merchant_items[index] = item

	# update registry in MerchantRegistry autoload (if present)
	if typeof(MerchantRegistry) != TYPE_NIL and MerchantRegistry != null:
		MerchantRegistry.set_items(_get_registry_key(), merchant_items)

	# emit update (state is kept in-memory for this runtime)
	emit_signal("merchant_updated", _get_data())
	return true


# Persistence removed: merchants keep state only in memory for the current session.

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
			"price": price,
			# allow config to specify package size; fallback to sell_batch
			"buy_amount": int(m.get("buy_amount", sell_batch))
		})

		current_weight += item_weight
