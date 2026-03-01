class_name InventoryInteraction
extends RefCounted

var _store: InventoryStoreAdapter = null
var _item_scene: PackedScene = null
var _debug: bool = false

var _get_ui_cb: Callable = Callable()
var _get_mouse_pos_cb: Callable = Callable()
var _validate_slot_cb: Callable = Callable()


func _init(
	store: InventoryStoreAdapter,
	item_scene: PackedScene,
	debug: bool,
	get_ui_cb: Callable,
	get_mouse_pos_cb: Callable,
	validate_slot_cb: Callable
) -> void:
	_store = store
	_item_scene = item_scene
	_debug = debug
	_get_ui_cb = get_ui_cb
	_get_mouse_pos_cb = get_mouse_pos_cb
	_validate_slot_cb = validate_slot_cb


func handle_slot_gui_input(event: InputEvent, slot: Node) -> void:
	if not (event is InputEventMouseButton):
		return

	var mbe: InputEventMouseButton = event as InputEventMouseButton
	if not mbe.pressed:
		return

	if mbe.button_index == MOUSE_BUTTON_RIGHT:
		right_click_put_one_unit(slot)
		return

	var ui := _require_ui_with_holding()
	if ui == null:
		return

	var holding: Variant = ui.get("holding_item")
	var slot_item: Variant = null
	if InventoryUtils.has_property(slot, &"item"):
		slot_item = slot.get("item")

	if holding != null:
		if slot_item == null:
			left_click_empty_slot(slot)
		else:
			var holding_name: String = str((holding as Node).get("item_name"))
			var slot_name: String = str((slot_item as Node).get("item_name"))
			if holding_name != slot_name:
				left_click_different_item(slot)
			else:
				left_click_same_item(slot)
	elif slot_item != null:
		left_click_not_holding(slot)


func _require_ui_with_holding() -> Node:
	if not _get_ui_cb.is_valid():
		push_error("InventoryInteraction: UI Callback ist ungültig")
		return null

	var ui: Node = _get_ui_cb.call()
	if ui == null:
		push_error("UserInterface Parent nicht gefunden. Node muss so heißen.")
		return null

	if not InventoryUtils.has_property(ui, &"holding_item"):
		push_error("UserInterface hat keine Variable 'holding_item'")
		return null

	return ui


func _require_holding_node(ui: Node) -> Node:
	if ui == null:
		return null
	return get_holding_node(ui)


func get_holding_node(ui: Node) -> Node:
	var can_proceed := ui != null and InventoryUtils.has_property(ui, &"holding_item")
	if not can_proceed:
		return null

	var holding: Variant = ui.get("holding_item")
	if holding is Node and is_instance_valid(holding as Node):
		return holding as Node
	return null


func get_slot_item_node(slot: Node) -> Node:
	var can_proceed := InventoryUtils.has_property(slot, &"item")
	if not can_proceed:
		return null

	var slot_item: Variant = slot.get("item")
	if slot_item is Node and is_instance_valid(slot_item as Node):
		return slot_item as Node
	return null


func put_item_into_slot(slot: Node, item: Node) -> bool:
	if slot.has_method("put_into_slot"):
		slot.call("put_into_slot", item)
		return true
	push_error("Slot hat keine put_into_slot()")
	return false


func decrease_holding_quantity(ui: Node, hnode: Node, amount: int) -> void:
	if ui == null or hnode == null or amount <= 0:
		return

	if hnode.has_method("decrease_item_quantity"):
		hnode.call("decrease_item_quantity", amount)
	else:
		var cur_qty := int(hnode.get("item_quantity"))
		hnode.set("item_quantity", max(0, cur_qty - amount))

	if int(hnode.get("item_quantity")) <= 0:
		if is_instance_valid(hnode):
			hnode.queue_free()
		ui.set("holding_item", null)


func create_single_item_node(item_name: String) -> Node:
	var can_proceed := _item_scene != null
	if not can_proceed:
		push_error("ITEM_SCENE ist null")
		return null

	var new_item = _item_scene.instantiate()
	can_proceed = new_item != null
	if not can_proceed:
		push_error("Failed to instantiate ITEM_SCENE")
		return null

	if not new_item.has_method("set_item"):
		push_error("Instantiated item has no set_item()")
		if is_instance_valid(new_item):
			new_item.queue_free()
		can_proceed = false

	if not can_proceed:
		return null

	new_item.call("set_item", item_name, 1)
	return new_item


func left_click_empty_slot(slot: Node) -> void:
	var ui := _require_ui_with_holding()
	if ui == null:
		return

	var holding := _require_holding_node(ui)
	if holding == null:
		return

	if not _add_item_to_empty_slot(holding, slot):
		return

	if not put_item_into_slot(slot, holding):
		return

	ui.set("holding_item", null)
	_call_validate(slot)


func left_click_different_item(slot: Node) -> void:
	var ui := _require_ui_with_holding()
	if ui == null:
		return

	var holding := _require_holding_node(ui)
	if holding == null:
		return

	_remove_inventory_item_without_signals(slot)
	_add_item_to_empty_slot(holding, slot)
	var temp_item: Node = get_slot_item_node(slot)

	if slot.has_method("pick_from_slot"):
		slot.call("pick_from_slot")
	else:
		push_error("Slot hat keine pick_from_slot()")
		return

	if temp_item != null:
		temp_item.global_position = _mouse_position()

	if not put_item_into_slot(slot, holding):
		return

	ui.set("holding_item", temp_item)
	_call_validate(slot)


func left_click_same_item(slot: Node) -> void:
	var ui := _require_ui_with_holding()
	var can_proceed := ui != null

	var holding: Node = null
	if can_proceed:
		holding = _require_holding_node(ui)
		can_proceed = holding != null

	if can_proceed and not InventoryUtils.has_property(slot, &"item"):
		push_error("Slot hat keine Property 'item'")
		can_proceed = false

	var slot_item: Node = null
	if can_proceed:
		slot_item = get_slot_item_node(slot)
		can_proceed = slot_item != null

	var item_data: Dictionary = {}
	if can_proceed:
		item_data = _get_item_data()
		if item_data.is_empty():
			push_error("JsonData.item_data fehlt, StackSize kann nicht gelesen werden!")
			can_proceed = false

	var name: String = ""
	if can_proceed:
		name = str(slot_item.get("item_name"))
		if not item_data.has(name):
			push_error("JsonData.item_data hat kein Item '%s'" % name)
			can_proceed = false
		elif (
			not (item_data[name] is Dictionary)
			or not (item_data[name] as Dictionary).has("StackSize")
		):
			push_error("Item '%s' hat keinen StackSize Eintrag" % name)
			can_proceed = false

	if not can_proceed:
		return

	var stack_size: int = int((item_data[name] as Dictionary)["StackSize"])
	var slot_qty: int = int(slot_item.get("item_quantity"))
	var holding_qty: int = int(holding.get("item_quantity"))

	var able_to_add: int = stack_size - slot_qty
	if able_to_add <= 0:
		return

	if able_to_add >= holding_qty:
		_add_item_quantity(slot, holding_qty)
		if slot_item.has_method("add_item_quantity"):
			slot_item.call("add_item_quantity", holding_qty)
		decrease_holding_quantity(ui, holding, holding_qty)
	else:
		_add_item_quantity(slot, able_to_add)
		if slot_item.has_method("add_item_quantity"):
			slot_item.call("add_item_quantity", able_to_add)
		decrease_holding_quantity(ui, holding, able_to_add)

	_call_validate(slot)


func left_click_not_holding(slot: Node) -> void:
	var ui := _require_ui_with_holding()
	if ui == null:
		push_error("UI ist null")
		return

	if not InventoryUtils.has_property(slot, &"item"):
		push_error("Slot hat keine Property 'item'")
		return

	var slot_item: Node = get_slot_item_node(slot)
	if slot_item == null:
		return

	_remove_inventory_item_without_signals(slot)
	ui.set("holding_item", slot_item)
	if slot.has_method("pick_from_slot"):
		slot.call("pick_from_slot")
	else:
		push_error("Slot hat keine pick_from_slot()")
		return

	if is_instance_valid(slot_item):
		slot_item.global_position = _mouse_position()

	_call_validate(slot)


func right_click_put_one_unit(slot: Node) -> void:
	var ui := _require_ui_with_holding()
	if ui == null:
		return

	var hnode := _require_holding_node(ui)
	if hnode == null:
		return

	var holding_name: String = str(hnode.get("item_name"))
	var holding_qty: int = int(hnode.get("item_quantity"))
	var slot_item: Node = get_slot_item_node(slot)

	if slot_item == null:
		if holding_qty <= 1:
			left_click_empty_slot(slot)
		else:
			var new_item: Node = create_single_item_node(holding_name)
			var can_place_item := new_item != null

			if can_place_item:
				can_place_item = _add_item_to_empty_slot(new_item, slot)
				if not can_place_item and is_instance_valid(new_item):
					new_item.queue_free()

			if can_place_item:
				can_place_item = put_item_into_slot(slot, new_item)
				if not can_place_item and is_instance_valid(new_item):
					new_item.queue_free()

			if can_place_item:
				decrease_holding_quantity(ui, hnode, 1)
				_call_validate(slot)
	else:
		var slot_name := str(slot_item.get("item_name"))
		if slot_name == holding_name:
			_add_item_quantity(slot, 1)
			if slot_item.has_method("add_item_quantity"):
				slot_item.call("add_item_quantity", 1)
			decrease_holding_quantity(ui, hnode, 1)
			_call_validate(slot)
		else:
			left_click_different_item(slot)


func _remove_inventory_item_without_signals(slot: Node) -> void:
	if _store == null:
		push_error("InventoryInteraction: Store ist null")
		return

	_store.set_block_signals(true)
	_store.remove_item(slot)
	_store.set_block_signals(false)


func _add_item_to_empty_slot(item: Node, slot: Node) -> bool:
	if _store == null:
		push_error("InventoryInteraction: Store ist null")
		return false
	return _store.add_item_to_empty_slot(item, slot)


func _add_item_quantity(slot: Node, amount: int) -> void:
	if _store == null:
		push_error("InventoryInteraction: Store ist null")
		return
	_store.add_item_quantity(slot, amount)


func _get_item_data() -> Dictionary:
	if _store == null:
		push_error("InventoryInteraction: Store ist null")
		return {}
	return _store.get_item_data()


func _mouse_position() -> Vector2:
	if _get_mouse_pos_cb.is_valid():
		var p: Variant = _get_mouse_pos_cb.call()
		if p is Vector2:
			return p as Vector2
	return Vector2.ZERO


func _call_validate(slot: Node) -> void:
	if not _debug:
		return
	if _validate_slot_cb.is_valid():
		_validate_slot_cb.call(slot)
