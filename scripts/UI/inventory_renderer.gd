class_name InventoryRenderer
extends RefCounted

var _store: InventoryStoreAdapter = null
var _get_slots_cb: Callable = Callable()
var _get_holding_cb: Callable = Callable()
var _ensure_selection_cb: Callable = Callable()


func _init(
	store: InventoryStoreAdapter,
	get_slots_cb: Callable,
	get_holding_cb: Callable,
	ensure_selection_cb: Callable
) -> void:
	_store = store
	_get_slots_cb = get_slots_cb
	_get_holding_cb = get_holding_cb
	_ensure_selection_cb = ensure_selection_cb


func render() -> void:
	if _store == null:
		push_error("InventoryRenderer: Store ist null")
		return

	var holding: Node = null
	if _get_holding_cb.is_valid():
		var h = _get_holding_cb.call()
		if h is Node:
			holding = h as Node

	if not _store.has_inventory():
		push_error("PlayerInventory hat keine Variable 'inventory'")
		return

	if not _get_slots_cb.is_valid():
		push_error("InventoryRenderer: Slot Callback ist ungültig")
		return

	var slots: Array[Node] = _get_slots_cb.call()

	for i: int in range(slots.size()):
		var s: Node = slots[i]

		if s.has_method("clear_slot"):
			s.call("clear_slot")
		else:
			if InventoryUtils.has_property(s, &"item"):
				var it: Variant = s.get("item")
				if it != null and it is Node and is_instance_valid(it):
					if not (holding != null and it == holding):
						(it as Node).queue_free()
				s.set("item", null)

		if s.has_method("refresh_style"):
			s.call("refresh_style")

	var inv: Dictionary = _store.get_inventory()
	var keys: Array = inv.keys()

	for k in keys:
		var idx: int = int(k)
		if idx < 0 or idx >= slots.size():
			push_error(
				"Inventory enthält slot_index %s, aber UI hat nur %d Slots" % [str(k), slots.size()]
			)
			continue

		var slot: Node = slots[idx]
		var data: Variant = inv[k]

		if typeof(data) != TYPE_ARRAY:
			push_error("Ungültige Inventory Daten in Slot %d: %s" % [idx, str(data)])
			continue

		var arr: Array = data as Array
		if arr.size() < 2:
			push_error("Ungültige Inventory Daten in Slot %d: %s" % [idx, str(arr)])
			continue

		var item_name: String = str(arr[0])
		var item_qty: int = int(arr[1])

		if slot.has_method("initialize_item"):
			slot.call("initialize_item", item_name, item_qty)
		else:
			push_error(
				"Slot %d hat initialize_item() nicht – Item kann nicht angezeigt werden" % idx
			)

	if _ensure_selection_cb.is_valid():
		_ensure_selection_cb.call()


func refresh_slot_style(slot: Node) -> void:
	if slot != null and is_instance_valid(slot) and slot.has_method("refresh_style"):
		slot.call("refresh_style")


func refresh_all_slot_styles(slots: Array[Node]) -> void:
	for s in slots:
		refresh_slot_style(s)
