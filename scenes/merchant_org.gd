extends VBoxContainer

@export var merchant_slot: String = "res://scenes/merchant_slot.tscn"
@export var num_of_slots: int = 3
@export var seed: int = 213311312
@export var price_icon_path: String = "res://assets/menu/UI_TravelBook_IconStar01a.png"

func _ready() -> void:
	# This script requires JsonData autoload with `item_data` available.
	if typeof(JsonData) == TYPE_NIL or JsonData == null or not ("item_data" in JsonData):
		push_error("JsonData.item_data must be available (add JsonData as autoload)")
		return

	var items: Dictionary = JsonData.item_data
	var keys = items.keys()
	if keys == []:
		push_warning("JsonData.item_data is empty")
		return

	# Load merchant slot scene if provided
	var slot_scene: PackedScene = null
	if merchant_slot != null and str(merchant_slot) != "":
		var loaded = ResourceLoader.load(merchant_slot)
		if loaded is PackedScene:
			slot_scene = loaded

	# Prepare RNG with given seed for reproducible prices
	var rng = RandomNumberGenerator.new()
	rng.seed = int(seed)

	# Create the merchant slot containers
	var merchants: Array = []
	for i in range(num_of_slots):
		var node: Control
		if slot_scene != null:
			var inst = slot_scene.instantiate()
			if inst is Control:
				node = inst
			else:
				node = VBoxContainer.new()
				node.add_child(inst)
		else:
			node = VBoxContainer.new()
		node.name = "Merchant_%d" % i
		add_child(node)
		merchants.append(node)

	# Distribute items round-robin across merchant slots
	for idx in range(keys.size()):
		var key = keys[idx]
		var data = items[key]
		var merchant_node = merchants[idx % merchants.size()]
		print("verkauf:", key)
		_add_item_to_merchant(merchant_node, key, data, rng)


func _add_item_to_merchant(
	merchant_node: Control,
	item_key: String,
	item_data: Dictionary,
	rng: RandomNumberGenerator
) -> void:

	# Use the provided merchant_node itself when it already looks like a slot
	var slot_ui: Node = null
	if merchant_node.has_node("price") or merchant_node.has_node("item") or merchant_node.has_method("set_price"):
		slot_ui = merchant_node
	else:
		var slot_scene: PackedScene = ResourceLoader.load(merchant_slot)
		if slot_scene == null:
			push_error("Merchant slot scene missing")
			return
		slot_ui = slot_scene.instantiate()
		merchant_node.add_child(slot_ui)

	# Try to find a child node that can be initialized with the item.
	# Common node names in this project are "item" or "Slot"; be robust and also
	# search children for a node exposing `initialize_item`.
	var init_target: Node = null
	if slot_ui.has_node("item"):
		init_target = slot_ui.get_node("item")
	elif slot_ui.has_node("Slot"):
		init_target = slot_ui.get_node("Slot")
	else:
		for child in slot_ui.get_children():
			if child is Node and child.has_method("initialize_item"):
				init_target = child
				break

	if init_target != null and init_target.has_method("initialize_item"):
		init_target.initialize_item(item_key, 1)
		print("initialized item on slot:", item_key)

	# Set item_name on the slot UI if supported so buy-box can reference it
	if slot_ui != null:
		if "item_name" in slot_ui:
			slot_ui.item_name = item_key
		# Also set item's icon_path if available
		if "icon_path" in slot_ui and item_data.has("icon"):
			slot_ui.icon_path = str(item_data.get("icon"))

	# -------------------------
	# PREIS BERECHNEN
	# -------------------------
	var price_val := 1
	if item_data.has("buy_price"):
		var bp = item_data.buy_price
		price_val = rng.randi_range(
			int(bp.get("min", 1)),
			int(bp.get("max", 1))
		)

	if slot_ui.has_method("set_price"):
		if "icon_path" in slot_ui:
			slot_ui.icon_path = price_icon_path
		slot_ui.call("set_price", price_val)
		return

	# Otherwise, try to find the price container and set icon/label there
	var price_node = slot_ui.get_node_or_null("price")
	if price_node != null:
		# If there's already an Icon TextureRect, set its texture, otherwise create one
		var tex: Texture = null
		if price_icon_path != null and str(price_icon_path) != "":
			var tres = ResourceLoader.load(price_icon_path)
			if tres is Texture:
				tex = tres

		var icon_rect: TextureRect = price_node.get_node_or_null("Icon") as TextureRect
		if icon_rect != null and tex != null:
			icon_rect.texture = tex
		elif icon_rect == null and tex != null:
			icon_rect = TextureRect.new()
			icon_rect.name = "Icon"
			icon_rect.texture = tex
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			price_node.add_child(icon_rect)

		var lbl = price_node.get_node_or_null("Label") as Label
		if lbl != null:
			lbl.text = str(price_val)
		else:
			# If price_node itself is a Label
			if price_node is Label:
				(price_node as Label).text = str(price_val)
