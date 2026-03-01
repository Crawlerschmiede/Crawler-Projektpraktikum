class_name InventoryStoreAdapter
extends RefCounted

var _inventory_autoload: Node = null
var _json_data_autoload: Node = null


func _init(inventory_autoload: Node = null, json_data_autoload: Node = null) -> void:
	_inventory_autoload = inventory_autoload
	_json_data_autoload = json_data_autoload


func connect_inventory_changed(target: Object, method_name: StringName) -> bool:
	if _inventory_autoload == null or target == null:
		return false
	if not _inventory_autoload.has_signal("inventory_changed"):
		return false

	var cb := Callable(target, method_name)
	if not _inventory_autoload.inventory_changed.is_connected(cb):
		_inventory_autoload.inventory_changed.connect(cb)
	return true


func register_slot_index(idx: int, groups: Array[StringName]) -> void:
	if _inventory_autoload == null:
		return
	if _inventory_autoload.has_method("register_slot_index"):
		_inventory_autoload.register_slot_index(idx, groups)


func has_inventory() -> bool:
	return (
		_inventory_autoload != null
		and InventoryUtils.has_property(_inventory_autoload, &"inventory")
	)


func get_inventory() -> Dictionary:
	if not has_inventory():
		return {}
	return _inventory_autoload.get("inventory")


func get_selected_slot() -> int:
	if _inventory_autoload == null:
		return -1
	if _inventory_autoload.has_method("get_selected_slot"):
		return int(_inventory_autoload.get_selected_slot())
	if InventoryUtils.has_property(_inventory_autoload, &"selected_slot"):
		return int(_inventory_autoload.selected_slot)
	return -1


func set_selected_slot(value: int) -> void:
	if _inventory_autoload == null:
		return
	if _inventory_autoload.has_method("set_selectet_slot"):
		_inventory_autoload.set_selectet_slot(value)
		return
	if InventoryUtils.has_property(_inventory_autoload, &"selected_slot"):
		_inventory_autoload.selected_slot = value


func remove_item(slot: Node) -> void:
	if _inventory_autoload == null:
		return
	if _inventory_autoload.has_method("remove_item"):
		_inventory_autoload.remove_item(slot)


func add_item_to_empty_slot(item: Node, slot: Node) -> bool:
	if _inventory_autoload == null:
		return false
	if _inventory_autoload.has_method("add_item_to_empty_slot"):
		return bool(_inventory_autoload.add_item_to_empty_slot(item, slot))
	return false


func add_item_quantity(slot: Node, amount: int) -> void:
	if _inventory_autoload == null:
		return
	if _inventory_autoload.has_method("add_item_quantity"):
		_inventory_autoload.add_item_quantity(slot, amount)


func set_block_signals(value: bool) -> void:
	if _inventory_autoload == null:
		return
	if _inventory_autoload.has_method("set_block_signals"):
		_inventory_autoload.set_block_signals(value)


func emit_changed() -> void:
	if _inventory_autoload == null:
		return
	if _inventory_autoload.has_method("_emit_changed"):
		_inventory_autoload._emit_changed()
	elif has_inventory():
		_inventory_autoload.inventory = _inventory_autoload.get("inventory")


func swap_slots_by_index(a_idx: int, b_idx: int) -> bool:
	if not has_inventory():
		return false

	var inv: Dictionary = get_inventory()
	var a = inv.get(a_idx, null)
	var b = inv.get(b_idx, null)

	if a == null and b == null:
		return false

	if b == null:
		inv[b_idx] = a
		inv.erase(a_idx)
	elif a == null:
		inv[a_idx] = b
		inv.erase(b_idx)
	else:
		inv[a_idx] = b
		inv[b_idx] = a

	emit_changed()
	return true


func has_item_data() -> bool:
	return (
		_json_data_autoload != null
		and InventoryUtils.has_property(_json_data_autoload, &"item_data")
	)


func get_item_data() -> Dictionary:
	if not has_item_data():
		return {}
	return _json_data_autoload.get("item_data")


func get_item_group(item_name: String) -> Variant:
	if _inventory_autoload == null:
		return null
	if _inventory_autoload.has_method("_get_item_group"):
		return _inventory_autoload._get_item_group(item_name)
	return null
