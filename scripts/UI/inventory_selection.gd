class_name InventorySelection
extends RefCounted

var _store: InventoryStoreAdapter = null

var _get_inventory_slots_cb: Callable = Callable()
var _refresh_slot_style_cb: Callable = Callable()
var _refresh_all_styles_cb: Callable = Callable()
var _swap_slots_cb: Callable = Callable()
var _get_hotbar_slots_cb: Callable = Callable()
var _get_slots_cb: Callable = Callable()
var _is_equip_blocked_cb: Callable = Callable()


func _init(store: InventoryStoreAdapter, callbacks: InventorySelectionCallbacks) -> void:
	_store = store
	if callbacks == null:
		return
	_get_inventory_slots_cb = callbacks.get_inventory_slots
	_refresh_slot_style_cb = callbacks.refresh_slot_style
	_refresh_all_styles_cb = callbacks.refresh_all_styles
	_swap_slots_cb = callbacks.swap_slots
	_get_hotbar_slots_cb = callbacks.get_hotbar_slots
	_get_slots_cb = callbacks.get_slots
	_is_equip_blocked_cb = callbacks.is_equip_blocked


func ensure_inventory_selection() -> void:
	var inv_slots: Array = _get_inventory_slot_nodes_sorted()
	if inv_slots.size() == 0:
		return

	var cur := _get_selected_slot_index()
	var found := false
	for s in inv_slots:
		if int(s.get("slot_index")) == int(cur):
			found = true
			break

	if not found:
		var def_idx := int(inv_slots[0].get("slot_index"))
		_set_selected_slot_index(def_idx)

	_refresh_all_slot_styles()


func move_inventory_selection(delta: int) -> void:
	var inv_slots: Array = _get_inventory_slot_nodes_sorted()
	if inv_slots.size() == 0:
		return

	var slots: Array = []
	for s in inv_slots:
		if s != null and is_instance_valid(s) and InventoryUtils.has_property(s, &"slot_index"):
			slots.append(s)

	if slots.size() == 0:
		return

	var cur := _get_selected_slot_index()

	var idx := -1
	for i in range(slots.size()):
		if int(slots[i].get("slot_index")) == cur:
			idx = i
			break

	if idx == -1:
		if delta > 0:
			idx = 0
		else:
			idx = slots.size() - 1

	var new_idx = clamp(idx + delta, 0, slots.size() - 1)

	var new_slot_node: Node = slots[new_idx]
	var new_slot_index: int = int(new_slot_node.get("slot_index"))

	var prev_node: Node = null
	if idx >= 0 and idx < slots.size():
		prev_node = slots[idx]

	_set_selected_slot_index(new_slot_index)
	_refresh_slot_style(prev_node)
	_refresh_slot_style(new_slot_node)

	if new_slot_node is Control:
		(new_slot_node as Control).grab_focus()


func swap_inventory_with_hotbar(hotbar_number: int) -> void:
	var hotbar_nodes: Array = _get_hotbar_slot_nodes_sorted()
	if hotbar_number < 1 or hotbar_number > hotbar_nodes.size():
		return

	var hot_node: Node = hotbar_nodes[hotbar_number - 1]
	if hot_node == null:
		return

	var inv_idx: int = _get_selected_slot_index()
	var hot_idx: int = -1
	if hot_node.has_method("get"):
		hot_idx = int(hot_node.get("slot_index"))
	else:
		return

	if inv_idx < 0 or hot_idx < 0:
		return

	_swap_slots_by_index(inv_idx, hot_idx)


func is_hotbar_number_key(key: InputEventKey) -> bool:
	return key.unicode >= 49 and key.unicode <= 53


func try_handle_hotbar_swap(key: InputEventKey) -> bool:
	if not is_hotbar_number_key(key):
		return false

	var num := key.unicode - 48
	var hotbar_count := _get_hotbar_slot_nodes_sorted().size()
	if hotbar_count <= 0:
		return false

	var mapped = clamp(hotbar_count - num + 1, 1, hotbar_count)
	swap_inventory_with_hotbar(mapped)
	return true


func try_equip_selected_slot() -> bool:
	var can_equip := _store != null and _store.has_inventory()
	if not can_equip:
		return false

	if _is_equip_blocked():
		can_equip = false

	var sel_idx := _get_selected_slot_index()
	if sel_idx < 0:
		can_equip = false

	var inv: Dictionary = {}
	var data = null
	var item_group = null

	if can_equip:
		inv = _store.get_inventory()
		data = inv.get(sel_idx)
		if data == null:
			can_equip = false

	if can_equip:
		var item_name: String = str(data[0])
		item_group = _store.get_item_group(item_name)
		if item_group == null:
			can_equip = false

	var chosen_idx := -1
	if can_equip:
		for s in _get_slots():
			if not InventoryUtils.has_property(s, &"slot_index"):
				continue

			var tidx := int(s.get("slot_index"))
			if tidx < 0 or tidx > 6:
				continue
			if not s.is_in_group(item_group):
				continue

			if not inv.has(tidx):
				chosen_idx = tidx
				break

			if chosen_idx == -1:
				chosen_idx = tidx

	if chosen_idx < 0:
		can_equip = false

	if not can_equip:
		return false

	_swap_slots_by_index(sel_idx, chosen_idx)
	return true


func handle_unhandled_input(event: InputEvent, inventory_columns: int) -> bool:
	var handled := false

	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey

		if try_handle_hotbar_swap(key):
			handled = true
		elif key.is_action_pressed("ui_left"):
			move_inventory_selection(1)
			handled = true
		elif key.is_action_pressed("ui_right"):
			move_inventory_selection(-1)
			handled = true
		elif key.is_action_pressed("ui_up"):
			move_inventory_selection(inventory_columns if inventory_columns > 0 else 1)
			handled = true
		elif key.is_action_pressed("ui_down"):
			move_inventory_selection(-inventory_columns if inventory_columns > 0 else -1)
			handled = true
		elif key.is_action_pressed("ui_accept"):
			handled = try_equip_selected_slot()

	return handled


func _get_inventory_slot_nodes_sorted() -> Array:
	if not _get_inventory_slots_cb.is_valid():
		return []
	return _get_inventory_slots_cb.call()


func _get_hotbar_slot_nodes_sorted() -> Array:
	if not _get_hotbar_slots_cb.is_valid():
		return []
	return _get_hotbar_slots_cb.call()


func _get_slots() -> Array:
	if not _get_slots_cb.is_valid():
		return []
	return _get_slots_cb.call()


func _get_selected_slot_index() -> int:
	if _store == null:
		return -1
	return _store.get_selected_slot()


func _set_selected_slot_index(value: int) -> void:
	if _store != null:
		_store.set_selected_slot(value)


func _swap_slots_by_index(a_idx: int, b_idx: int) -> void:
	if _swap_slots_cb.is_valid():
		_swap_slots_cb.call(a_idx, b_idx)


func _refresh_slot_style(slot: Node) -> void:
	if _refresh_slot_style_cb.is_valid():
		_refresh_slot_style_cb.call(slot)


func _refresh_all_slot_styles() -> void:
	if _refresh_all_styles_cb.is_valid():
		_refresh_all_styles_cb.call()


func _is_equip_blocked() -> bool:
	if not _is_equip_blocked_cb.is_valid():
		return false
	return bool(_is_equip_blocked_cb.call())
