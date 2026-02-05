extends HBoxContainer

var _last_item_name: String = ""
var _sell_unit_price: int = 0
var _rng := RandomNumberGenerator.new()
var _register_attempts: int = 0
var _merchant_sell_prices: Dictionary = {}

# The scene may attach this script either to a parent HBoxContainer
# (with children named "Sell Slot", "Price", "Hammer") or directly
# to the "Sell Slot" Panel node. Resolve nodes flexibly.
@onready var sell_item_input_slot = $"Sell Slot" if has_node("Sell Slot") else self
@onready var sell_item_price = (
	$Price
	if has_node("Price")
	else (
		get_parent().get_node("Price")
		if get_parent() != null and get_parent().has_node("Price")
		else null
	)
)
@onready var sell_button = (
	$Hammer
	if has_node("Hammer")
	else (
		get_parent().get_node("Hammer")
		if get_parent() != null and get_parent().has_node("Hammer")
		else null
	)
)


func set_merchant_sell_prices(prices: Dictionary) -> void:
	if prices == null:
		_merchant_sell_prices = {}
		return
	_merchant_sell_prices = prices.duplicate(true)


func _register_sell_slot() -> void:
	_register_attempts += 1
	if sell_item_input_slot == null:
		return

	# ensure slot_index set
	if sell_item_input_slot.has_method("get"):
		var idx = (
			sell_item_input_slot.get("slot_index")
			if sell_item_input_slot.get("slot_index") != null
			else -1
		)
		if int(idx) < 0:
			sell_item_input_slot.set("slot_index", 23)
			print("[SellSlot] set slot_index -> 23")

	# wait for PlayerInventory to be available
	if (
		typeof(PlayerInventory) == TYPE_NIL
		or PlayerInventory == null
		or not PlayerInventory.has_method("register_slot_index")
	):
		if _register_attempts < 10:
			# try again next idle frame
			call_deferred("_register_sell_slot")
		else:
			push_warning(
				"[SellSlot] PlayerInventory.register_slot_index not available after retries"
			)
		return

	var groups = []
	if sell_item_input_slot != null:
		groups = sell_item_input_slot.get_groups()

	PlayerInventory.register_slot_index(23, groups)
	print("[SellSlot] registered slot 23 with groups:", groups)

	# Connect inner slot gui_input so drops/clicks are handled
	if sell_item_input_slot.has_method("gui_input"):
		var cb_sell: Callable = Callable(self, "_on_sell_slot_gui_input")
		if not sell_item_input_slot.gui_input.is_connected(cb_sell):
			sell_item_input_slot.gui_input.connect(cb_sell)
			print("[SellSlot] connected gui_input on inner sell slot")


func _has_property(obj: Object, prop: StringName) -> bool:
	if obj == null:
		return false
	var plist: Array[Dictionary] = obj.get_property_list()
	for p: Dictionary in plist:
		if p.has("name") and StringName(p["name"]) == prop:
			return true
	return false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	# connect hammer click
	if sell_button != null:
		sell_button.mouse_filter = Control.MOUSE_FILTER_STOP
		sell_button.connect("gui_input", Callable(self, "_on_hammer_gui_input"))
	# Ensure the inner Sell Slot has a valid slot_index so PlayerInventory can accept drops.
	# Defer registration to avoid race with PlayerInventory readiness
	if sell_item_input_slot != null:
		# mark the inner slot (and this container) as SellSlot so the Inventory UI
		# includes it in the global slot list even if it's outside the normal grids
		if sell_item_input_slot != null and sell_item_input_slot is Node:
			if not sell_item_input_slot.is_in_group("SellSlot"):
				sell_item_input_slot.add_to_group("SellSlot")
		if not is_in_group("SellSlot"):
			add_to_group("SellSlot")

		call_deferred("_register_sell_slot")


func _process(_delta: float) -> void:
	# detect item in sell slot and update price display when changed
	if sell_item_input_slot == null:
		return

	var it = null
	if sell_item_input_slot.has_method("get_item"):
		it = sell_item_input_slot.get_item()

	if it == null:
		if _last_item_name != "":
			_last_item_name = ""
			_sell_unit_price = 0
			if sell_item_price != null and sell_item_price.has_method("initialize_item"):
				sell_item_price.initialize_item("Coin", 0)
		return

	# read item name/quantity from the InventoryItem node
	var name := ""
	var qty := 1
	if it.has_method("get") or it.has_method("set_item"):
		# InventoryItem exposes `item_name` and `item_quantity`
		if typeof(it.item_name) != TYPE_NIL:
			name = str(it.item_name)
		if typeof(it.item_quantity) != TYPE_NIL:
			qty = int(it.item_quantity)

	if name == "":
		return

	if name != _last_item_name:
		# Prefer merchant-specific fixed sell price if available
		if _merchant_sell_prices != null and _merchant_sell_prices.has(name):
			_sell_unit_price = int(_merchant_sell_prices[name])
		else:
			# compute unit sell price: between min_price*(1-0.4) .. min_price
			var min_price := 0
			if JsonData != null and ("item_data" in JsonData) and JsonData.item_data.has(name):
				var info = JsonData.item_data[name]
				if (
					typeof(info) == TYPE_DICTIONARY
					and ("merchant" in info)
					and typeof(info["merchant"]) == TYPE_DICTIONARY
					and ("min_price" in info["merchant"])
				):
					min_price = int(info["merchant"]["min_price"])
			var discount := _rng.randf_range(0.0, 0.4)
			var unit := int(floor(float(max(min_price, 0)) * (1.0 - discount)))
			# ensure at least zero
			_sell_unit_price = max(unit, 0)

		var total_price = _sell_unit_price * max(qty, 1)
		if sell_item_price != null and sell_item_price.has_method("initialize_item"):
			sell_item_price.initialize_item("Coin", total_price)

		_last_item_name = name


func _on_hammer_gui_input(event: InputEvent) -> void:
	# sell: left mouse click
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
			_try_sell()


func _on_sell_slot_gui_input(event: InputEvent) -> void:
	# handle clicks/drops on the sell slot itself
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
			var ui := find_parent("UserInterface")
			if ui == null:
				return
			if not _has_property(ui, &"holding_item"):
				return
			var holding = ui.get("holding_item")
			if holding == null:
				return

			# Try to add to PlayerInventory at this sell slot
			if (
				typeof(PlayerInventory) != TYPE_NIL
				and PlayerInventory != null
				and PlayerInventory.has_method("add_item_to_empty_slot")
			):
				var ok: bool = PlayerInventory.add_item_to_empty_slot(holding, sell_item_input_slot)
				print("[SellSlot] add_item_to_empty_slot ->", ok)
				if ok:
					# put visual item into slot and clear holding
					if sell_item_input_slot.has_method("put_into_slot"):
						sell_item_input_slot.call("put_into_slot", holding)
					ui.set("holding_item", null)
					# ensure inventory UI refresh
					if PlayerInventory.has_method("_emit_changed"):
						PlayerInventory._emit_changed()
					return


func _try_sell() -> void:
	if sell_item_input_slot == null:
		return
	if not sell_item_input_slot.has_method("get_item"):
		return

	var it = sell_item_input_slot.get_item()
	if it == null:
		return

	var qty := 1
	if typeof(it.item_quantity) != TYPE_NIL:
		qty = int(it.item_quantity)

	var total = int(_sell_unit_price) * max(qty, 1)
	# give coins
	if (
		typeof(PlayerInventory) != TYPE_NIL
		and PlayerInventory != null
		and PlayerInventory.has_method("add_coins")
	):
		PlayerInventory.add_coins(total)

	# remove the item from the inventory backend (important!)
	if typeof(PlayerInventory) != TYPE_NIL and PlayerInventory != null:
		if PlayerInventory.has_method("remove_item"):
			PlayerInventory.remove_item(sell_item_input_slot)
		else:
			# fallback: remove by slot_index and emit change
			var idx = -1
			if sell_item_input_slot.has_method("get"):
				var v = sell_item_input_slot.get("slot_index")
				if v != null:
					idx = int(v)
			if idx >= 0:
				if PlayerInventory.has_method("inventory"):
					# best-effort erase
					PlayerInventory.inventory.erase(idx)
					if PlayerInventory.has_method("_emit_changed"):
						PlayerInventory._emit_changed()

	# remove the item from the slot (visual)
	if sell_item_input_slot.has_method("clear_slot"):
		sell_item_input_slot.clear_slot()

	# reset state and UI
	_last_item_name = ""
	_sell_unit_price = 0
	if sell_item_price != null and sell_item_price.has_method("initialize_item"):
		sell_item_price.initialize_item("Coin", 0)
