extends CharacterBody2D
class_name MerchantEntity

signal merchant_updated
signal player_entered_merchant
signal player_left_merchant

@export var seed := 0
@export var min_total_weight := 10
@export var max_total_weight := 15
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
	else:
		_generate_merchant_data()
		if typeof(MerchantRegistry) != TYPE_NIL and MerchantRegistry != null:
			MerchantRegistry.set_items(reg_key, merchant_items)

	print("merchant_items:", merchant_items)
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	print("BODY:", body)

	if body.is_in_group("player"):
		print("PLAYER DETECTED")
		print("Merchant items on enter:", merchant_items)
		# log registry when a player enters
		if typeof(MerchantRegistry) != TYPE_NIL and MerchantRegistry != null:
			var rk = _get_registry_key()
			print("[Merchant] loading registry key:", rk)
			print("[Merchant] registry content:", MerchantRegistry.get_registry())
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
func buy_item(index: int, amount: int = -1) -> void:
	# amount <=0 -> use sell_batch
	if amount <= 0:
		amount = sell_batch

	if index < 0 or index >= merchant_items.size():
		return

	var item = merchant_items[index]

	if item["count"] <= 0:
		return

	var to_buy = min(amount, int(item["count"]))
	if to_buy <= 0:
		return

	var total_price = int(item["price"]) * to_buy

	var rk := _get_registry_key()
	print("[Merchant] buy_item called; key=", rk, " index=", index, " to_buy=", to_buy)

	print("Before buy - merchant_items:", merchant_items)
	# try pay
	if not PlayerInventory.spend_coins(total_price):
		return

	# give player
	PlayerInventory.add_item(item["name"], to_buy)

	# reduce stock
	item["count"] = int(item["count"]) - to_buy
	if item["count"] < 0:
		item["count"] = 0
	merchant_items[index] = item

	# update registry in MerchantRegistry autoload (if present)
	if typeof(MerchantRegistry) != TYPE_NIL and MerchantRegistry != null:
		MerchantRegistry.set_items(_get_registry_key(), merchant_items)
		# always print registry after update
		print("[Merchant] registry after set:", MerchantRegistry.get_registry())

	print("After buy - merchant_items:", merchant_items)

	# emit update (state is kept in-memory for this runtime)
	emit_signal("merchant_updated", _get_data())


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
			"price": price
		})

		current_weight += item_weight
