extends Node

signal inventory_changed
signal item_picked_up(item_name: String, amount: int)
signal hp_changed(current: int, max: int)

const NUM_INVENTORY_SLOTS: int = 25

# slot_index -> [item_name: String, item_quantity: int]
var inventory: Dictionary = {}

var coins: int = 100

var _emit_pending: bool = false

var slot_group_by_index: Dictionary = {}

var suppress_signal: bool = false

var selected_slot: int = 18

# Player HP stored centrally in autoload (keeps player state across scenes)
var player_max_hp: int = 20
var player_hp: int = 20


func set_player_hp(current: int, max_hp_val: int) -> void:
	player_max_hp = int(max_hp_val)
	player_hp = int(current)
	if has_signal("hp_changed"):
		emit_signal("hp_changed", int(player_hp), int(player_max_hp))


func set_player_current_hp(current: int) -> void:
	player_hp = int(current)
	if has_signal("hp_changed"):
		emit_signal("hp_changed", int(player_hp), int(player_max_hp))


func set_player_max_hp(max_hp_val: int) -> void:
	player_max_hp = int(max_hp_val)
	if has_signal("hp_changed"):
		emit_signal("hp_changed", int(player_hp), int(player_max_hp))


func _ready() -> void:
	# initialize per-session merchant registry to persist merchant state in memory
	if get("merchant_registry") == null:
		set("merchant_registry", {})


func set_selectet_slot(slot: int) -> void:
	selected_slot = slot


func get_selected_slot() -> int:
	return selected_slot


func get_item_from_selected_slot():
	return inventory[get_selected_slot()]


func register_slot_index(idx: int, groups: Array[StringName]) -> void:
	slot_group_by_index[idx] = groups


func _get_item_group(item_name: String) -> String:
	if JsonData == null or not ("item_data" in JsonData):
		return "Inventory"

	var data: Dictionary = JsonData.item_data
	if not data.has(item_name):
		return "Inventory"

	var info: Variant = data[item_name]
	if typeof(info) != TYPE_DICTIONARY:
		return "Inventory"

	return str((info as Dictionary).get("group", "Inventory"))


func _slot_accepts_item(slot_node: Node, item_name: String) -> bool:
	if slot_node == null:
		print("[INV] slot_accepts_item: slot_node=null")
		return false

	var item_group: String = _get_item_group(item_name)

	# Debug Infos
	var slot_groups: Array[StringName] = slot_node.get_groups()
	print(
		"[INV] CHECK groups: slot=",
		slot_node.name,
		" slot_groups=",
		slot_groups,
		" item=",
		item_name,
		" item_group=",
		item_group
	)

	# Slot muss passende Gruppe haben
	if slot_node.is_in_group(item_group):
		print("[INV] ✅ OK: slot in group ", item_group)
		return true

	# Fallback
	if item_group == "Inventory" and slot_node.is_in_group("Inventory"):
		print("[INV] ✅ OK: Inventory fallback")
		return true

	print("[INV] ❌ DENY: group mismatch")
	return false


# ------------------------------------------------------
# Core Helpers
# ------------------------------------------------------
func _get_stack_size(item_name: String) -> int:
	if JsonData == null:
		return 1
	if not ("item_data" in JsonData):
		return 1

	var data: Dictionary = JsonData.item_data
	if not data.has(item_name):
		return 1

	var info: Variant = data[item_name]
	if typeof(info) != TYPE_DICTIONARY:
		return 1

	var stack_size: int = int((info as Dictionary).get("StackSize", 1))
	return max(stack_size, 1)


func _slot_index_from_slot(slot: Node) -> int:
	# robust, typed-safe Zugriff
	if slot == null:
		return -1
	if slot.has_method("get"):
		var v: Variant = slot.get("slot_index")
		if v != null:
			return int(v)
	return -1


# ------------------------------------------------------
# API for UI / Gameplay
# ------------------------------------------------------
func add_item(item_name: String, item_quantity: int = 1) -> void:
	if item_quantity <= 0:
		return

	var stack_size: int = _get_stack_size(item_name)
	item_picked_up.emit(item_name, item_quantity)

	# 1) vorhandene Stacks auffüllen
	for k in inventory.keys():
		var idx: int = int(k)
		var data: Array = inventory[idx]

		if data.size() < 2:
			continue

		if str(data[0]) != item_name:
			continue

		var current: int = int(data[1])
		var able_to_add: int = stack_size - current
		if able_to_add <= 0:
			continue

		var add_now: int = min(able_to_add, item_quantity)
		data[1] = current + add_now
		inventory[idx] = data
		item_quantity -= add_now

		if item_quantity <= 0:
			_emit_changed()
			return

	# 2) neue Slots belegen
	var wanted_group: String = _get_item_group(item_name)

	var indices: Array = slot_group_by_index.keys()

	indices.sort_custom(func(a, b): return _priority(int(a)) < _priority(int(b)))

	for k in indices:
		var i: int = int(k)

		if i == 17:
			continue

		if inventory.has(i):
			continue

		var slot_groups: Array = slot_group_by_index.get(i, [])
		if not (wanted_group in slot_groups):
			print("not the same: ", slot_groups, wanted_group)
			continue
		else:
			print("found: ", slot_groups, wanted_group)

		var put_now: int = min(stack_size, item_quantity)
		inventory[i] = [item_name, put_now]
		item_quantity -= put_now

		_emit_changed()

		if item_quantity <= 0:
			return

	# wenn wir hier sind: kein Platz
	_emit_changed()
	push_warning("Inventar voll! Item nicht vollständig hinzugefügt: %s" % item_name)


func can_add_amount(item_name: String, desired: int) -> int:
	# Returns how many of `item_name` can currently be added to the player's inventory
	if desired <= 0:
		return 0

	var stack_sz := _get_stack_size(item_name)
	var inv := inventory

	var total_space := 0
	# Count free space in existing stacks and empty slots
	for i in range(NUM_INVENTORY_SLOTS):
		if inv.has(i):
			var v = inv[i]
			if typeof(v) == TYPE_ARRAY and v.size() >= 2 and str(v[0]) == item_name:
				var cur := int(v[1])
				total_space += max(0, stack_sz - cur)
			# else: occupied by other item -> no space in this slot
		else:
			# empty slot -> full stack fits
			total_space += stack_sz

	return min(desired, total_space)


func _priority(i):
	if i >= 6 and i <= 16:
		return i  # höchste Priorität
	if i >= 1 and i <= 6:
		return 100 + i  # danach
	return 1000 + i  # Rest hinten


func _emit_changed() -> void:
	if suppress_signal:
		return
	if _emit_pending:
		return

	_emit_pending = true
	call_deferred("_emit_changed_deferred")


func _emit_changed_deferred() -> void:
	_emit_pending = false
	_rebuild_inventory()
	# Debug: Ausgabe aktuelles Inventory zur Fehlersuche
	print("[PlayerInventory] inventory after change: ", str(inventory))
	inventory_changed.emit()


func add_item_to_empty_slot(item_node: Node, slot_node: Node) -> bool:
	if item_node == null or slot_node == null:
		return false

	var idx: int = _slot_index_from_slot(slot_node)
	if idx < 0:
		push_error("add_item_to_empty_slot: Slot hat keinen gültigen slot_index")
		return false

	var nm: String = str(item_node.get("item_name"))
	var qt: int = int(item_node.get("item_quantity"))
	if nm == "" or qt <= 0:
		return false

	if not _slot_accepts_item(slot_node, nm):
		push_warning(
			(
				"Slot akzeptiert Item nicht (Group mismatch)! item='%s' group='%s'"
				% [nm, _get_item_group(nm)]
			)
		)
		return false

	inventory[idx] = [nm, qt]
	_emit_changed()
	return true


func remove_item(slot_node: Node) -> void:
	var idx: int = _slot_index_from_slot(slot_node)
	if idx < 0:
		return

	inventory.erase(idx)
	_emit_changed()


func add_item_quantity(slot_node: Node, amount: int) -> void:
	if amount <= 0:
		return

	var idx: int = _slot_index_from_slot(slot_node)
	if idx < 0:
		return

	if not inventory.has(idx):
		return

	var data: Array = inventory[idx]
	if data.size() < 2:
		return

	var nm: String = str(data[0])
	var stack_size: int = _get_stack_size(nm)

	var current: int = int(data[1])
	var new_value: int = min(stack_size, current + amount)

	data[1] = new_value
	inventory[idx] = data
	_emit_changed()


func clear_inventory() -> void:
	inventory.clear()
	_emit_changed()


func _rebuild_inventory() -> void:
	var new_inv: Dictionary = {}

	for k: Variant in inventory.keys():
		var idx: int = int(k)
		if idx < 0 or idx >= NUM_INVENTORY_SLOTS:
			continue

		var v: Variant = inventory[k]
		if typeof(v) != TYPE_ARRAY:
			continue

		var arr: Array = v as Array
		if arr.size() < 2:
			continue

		var nm: String = str(arr[0])
		var qt: int = int(arr[1])

		if nm == "" or qt <= 0:
			continue

		# normalisierte Form erzwingen
		new_inv[idx] = [nm, qt]

	inventory = new_inv


# ----------------------
# Coins API
# ----------------------
func has_coins(amount: int) -> bool:
	return int(coins) >= int(amount)


func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
	if not has_coins(amount):
		return false
	coins = int(coins) - int(amount)
	# Optionally emit inventory_changed so UI updates coin display
	_emit_changed()
	return true


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins = int(coins) + int(amount)
	_emit_changed()


func reset() -> void:
	# Clear runtime inventory state and reset to sane defaults
	inventory.clear()
	coins = 100
	slot_group_by_index.clear()
	suppress_signal = false
	selected_slot = 18

	# Reset player HP defaults
	player_max_hp = 20
	player_hp = 20
	_emit_changed()
