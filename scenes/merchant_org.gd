extends VBoxContainer

@export var merchant_slot: String = "res://scenes/merchant_slot.tscn"
@export var seed: int = 213311312

@export var min_total_weight := 10
@export var max_total_weight := 15

var slot_scene: PackedScene


func _ready() -> void:

	if JsonData == null or not ("item_data" in JsonData):
		push_error("JsonData.item_data missing!")
		return

	slot_scene = ResourceLoader.load(merchant_slot)
	if slot_scene == null:
		push_error("Merchant slot missing: " + merchant_slot)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	_generate_merchant(JsonData.item_data, rng)

func _generate_merchant(items: Dictionary, rng: RandomNumberGenerator) -> void:

	var target_weight := rng.randi_range(min_total_weight, max_total_weight)
	var current_weight := 0

	var keys := items.keys()
	keys.shuffle()

	for item_key in keys:

		if current_weight >= target_weight:
			break

		var data: Dictionary = items[item_key]

		if not data.has("merchant"):
			continue

		var m: Dictionary = data.merchant

		# ----------------
		# Chance
		# ----------------
		if m.has("chance") and rng.randf() > float(m.chance):
			continue

		# ----------------
		# Weight
		# ----------------
		var item_weight := int(m.get("weight", 1))

		if current_weight + item_weight > target_weight:
			continue

		# ----------------
		# Count
		# ----------------
		var min_c := int(m.get("min_count", 1))
		var max_c := int(m.get("max_count", min_c))
		var count := rng.randi_range(min_c, max_c)

		# ----------------
		# Price
		# ----------------
		var min_p := int(m.get("min_price", 1))
		var max_p := int(m.get("max_price", min_p))
		var price := rng.randi_range(min_p, max_p)

		# ----------------
		# Slot erzeugen
		# ----------------
		_create_slot(item_key, count, price)

		current_weight += item_weight

func _create_slot(item_key: String, count: int, price: int) -> void:

	var slot_ui = slot_scene.instantiate()
	add_child(slot_ui)

	slot_ui.item_name = item_key
	slot_ui.item_count = count
	slot_ui.price = price

	if slot_ui.has_method("_refresh"):
		slot_ui._refresh()
