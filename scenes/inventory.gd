# InventoryUI.gd (Godot 4.x, vollständig typisiert & compile-safe)

extends Control

signal inventory_changed

const DEBUG: bool = true

# Slot Script (Pfad prüfen!)
const SlotScript: GDScript = preload("res://scenes/Slot.gd")

var _ui: Node = null
var _slot_callables: Dictionary = {}  # key: Node (slot), value: Callable

@onready var inv_grid: GridContainer = $Inner/Equiptment
@onready var equip_grid: GridContainer = $Inner/GridContainer
@onready var hotbar_grid: GridContainer = $Hotbar/HotContainer


func _collect_slots_recursive(root: Node, out: Array[Node]) -> void:
	for c in root.get_children():
		if (
			c.has_method("initialize_item")
			and c.has_method("put_into_slot")
			and c.has_method("pick_from_slot")
		):
			out.append(c)
		else:
			if c.get_child_count() > 0:
				_collect_slots_recursive(c, out)


func _get_all_slots() -> Array[Node]:
	var out: Array[Node] = []
	_collect_slots_recursive(inv_grid, out)
	_collect_slots_recursive(equip_grid, out)
	_collect_slots_recursive(hotbar_grid, out)
	return out


# -------------------------
# Helpers: Property Check (Godot 4)
# -------------------------
func _has_property(obj: Object, prop: StringName) -> bool:
	if obj == null:
		return false
	var plist: Array[Dictionary] = obj.get_property_list()
	for p: Dictionary in plist:
		if p.has("name") and StringName(p["name"]) == prop:
			return true
	return false


func _get_ui() -> Node:
	if _ui != null and is_instance_valid(_ui):
		return _ui
	_ui = find_parent("UserInterface")
	return _ui


func _get_slots() -> Array[Node]:
	# get_children() liefert Array[Node], aber ohne typed generic → wir casten sauber.
	var children: Array = _get_all_slots()
	#print(children)
	var out: Array[Node] = []
	for n in children:
		if n is Node:
			out.append(n)
	return out


func _get_equipment_slots():
	var slots: Array[Node] = []
	_collect_slots_recursive(inv_grid, slots)
	var equipment_slots = []
	for slot in slots:
		print(slot.name)
		equipment_slots.append(slot)
	return equipment_slots


func get_equipment_skills():
	var equipment_slots = _get_equipment_slots()
	var gotten_skills = []
	for slot in equipment_slots:
		var item_in_slot = slot.get_item()
		if item_in_slot != null:
			var bound = slot.get_item().get_bound_skills()
			for skill in bound:
				if skill not in gotten_skills:
					gotten_skills.append(skill)
	return gotten_skills


# -------------------------
# Lifecycle
# -------------------------
func _ready() -> void:
	#dgb("_ready() gestartet")

	var slots: Array[Node] = _get_slots()
	#dgb("Slots im GridContainer gefunden: %d" % slots.size())

	if slots.is_empty():
		push_error("Keine Slots im GridContainer! Hast du Slot Panels als Children drin?")
		return

	_setup_slots(slots)
	_connect_inventory_signal()
	initialize_inventory()


func _setup_slots(slots: Array[Node]) -> void:
	for i: int in range(slots.size()):
		var s: Node = slots[i]

		if not (s is Control):
			push_error("Slot %d ist kein Control! gui_input geht nur bei Control-Nodes." % i)
			continue

		# Pflicht-API Slot
		if not s.has_method("initialize_item"):
			push_error("Slot %d hat keine Methode initialize_item(). Slot.gd fehlt/anders?" % i)

		var groups: Array[StringName] = (s as Node).get_groups()
		PlayerInventory.register_slot_index(i, groups)

		# Signal connect (Callable speichern, sonst is_connected() sinnlos)
		var call: Callable = Callable(self, "slot_gui_input").bind(s)
		_slot_callables[s] = call

		var ctrl: Control = s as Control
		if not ctrl.gui_input.is_connected(call):
			ctrl.gui_input.connect(call)

		# Slot properties setzen
		if _has_property(s, &"slot_index"):
			s.set("slot_index", i)
		else:
			push_error(
				(
					"Slot %d hat keine Property 'slot_index' (in Slot.gd: @export var slot_index:int)"
					% i
				)
			)

		if _has_property(s, &"slot_type"):
			s.set("slot_type", SlotScript.SlotType.INVENTORY)
		else:
			push_error(
				"Slot %d hat keine Property 'slot_type' (in Slot.gd: @export var slot_type:int)" % i
			)


func _connect_inventory_signal() -> void:
	if PlayerInventory != null and PlayerInventory.has_signal("inventory_changed"):
		var cb: Callable = Callable(self, "_on_inventory_changed")
		# connect using Callable (Godot 4 compatible) and avoid double-connections
		if not PlayerInventory.inventory_changed.is_connected(cb):
			PlayerInventory.inventory_changed.connect(cb)


func _on_inventory_changed() -> void:
	initialize_inventory()
	inventory_changed.emit()


# -------------------------
# Inventory -> UI Render
# -------------------------
func initialize_inventory() -> void:
	var ui := _get_ui()
	var holding: Node = null
	if ui != null and _has_property(ui, &"holding_item"):
		var hv: Node = ui.get("holding_item")
		if hv is Node:
			holding = hv as Node

	#dgb("initialize_inventory()")

	if PlayerInventory == null:
		push_error("PlayerInventory ist null – Autoload fehlt?")
		return

	if not _has_property(PlayerInventory, &"inventory"):
		push_error("PlayerInventory hat keine Variable 'inventory'")
		return

	var slots: Array[Node] = _get_slots()

	# 1) Slots leeren + style refresh
	for i: int in range(slots.size()):
		var s: Node = slots[i]

		if s.has_method("clear_slot"):
			s.call("clear_slot")
		else:
			# fallback: item property freigeben
			if _has_property(s, &"item"):
				var it: Variant = s.get("item")
				if it != null and it is Node and is_instance_valid(it):
					if not (holding != null and it == holding):
						(it as Node).queue_free()
				s.set("item", null)

		if s.has_method("refresh_style"):
			s.call("refresh_style")

	# 2) Inventory Daten neu reinbauen
	var inv: Dictionary = PlayerInventory.get("inventory")
	var keys: Array = inv.keys()
	#dgb("PlayerInventory.inventory keys: %s" % str(keys))

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

		#dgb("Slot %d <- %s x%d" % [idx, item_name, item_qty])

		if slot.has_method("initialize_item"):
			slot.call("initialize_item", item_name, item_qty)
		else:
			push_error(
				"Slot %d hat initialize_item() nicht – Item kann nicht angezeigt werden" % idx
			)


# -------------------------
# INPUT / DRAG HANDLING
# -------------------------
func slot_gui_input(event: InputEvent, slot: Node) -> void:
	#dgb("CLICK on slot " + str(slot.get("slot_index")))
	if not (event is InputEventMouseButton):
		return

	var mbe: InputEventMouseButton = event as InputEventMouseButton
	#dgb("InputEventMouseButton überprüfung")
	if mbe.button_index != MOUSE_BUTTON_LEFT or not mbe.pressed:
		return

	#dgb("Knopf erkannt")
	var ui: Node = _get_ui()
	if ui == null:
		push_error("UserInterface Parent nicht gefunden. Node muss so heißen.")
		return

	if not _has_property(ui, &"holding_item"):
		push_error("UserInterface hat keine Variable 'holding_item'")
		return

	var holding: Variant = ui.get("holding_item")

	var slot_item: Variant = null
	if _has_property(slot, &"item"):
		slot_item = slot.get("item")
	#dgb("holding startet?")

	# Wir halten was
	if holding != null:
		#dgb("holding not empty")
		if slot_item == null:
			#dgb("slot_item not empty")
			left_click_empty_slot(slot)
		else:
			var holding_name: String = str((holding as Node).get("item_name"))
			var slot_name: String = str((slot_item as Node).get("item_name"))

			if holding_name != slot_name:
				left_click_different_item(slot)
			else:
				left_click_same_item(slot)

	# Wir halten nix, Slot hat Item
	elif slot_item != null:
		left_click_not_holding(slot)


func _process(_delta: float) -> void:
	var ui: Node = _get_ui()
	if ui == null:
		return
	if not _has_property(ui, &"holding_item"):
		return

	var holding: Variant = ui.get("holding_item")
	if holding == null:
		return

	PlayerInventory.inventory.erase(17)

	if holding is Node and is_instance_valid(holding as Node):
		var hn := holding as Node
		hn.global_position = get_global_mouse_position()

		# Debug nur selten (nicht jeden Frame spammen)
		if DEBUG and (Engine.get_frames_drawn() % 30 == 0):
			#dgb("MOVE holding: parent=" + str(hn.get_parent()) + " pos=" + str(hn.global_position))
			if hn is CanvasItem:
				var hci := hn as CanvasItem


func able_to_put_into_slot(_slot: Node) -> bool:
	return true


func left_click_empty_slot(slot: Node) -> void:
	#dgb("left_click_empty_slot")
	var ui: Node = _get_ui()
	if ui == null:
		return

	var holding: Node = ui.get("holding_item")
	if holding == null:
		return

	var ok: bool = PlayerInventory.add_item_to_empty_slot(holding, slot)

	if not ok:
		#dgb("DROP denied -> item bleibt in Hand")
		return

	# ✅ nur wenn ok: UI ändern
	slot.call("put_into_slot", holding)
	ui.set("holding_item", null)

	var idx: int = int(slot.get("slot_index"))
	#print("I", idx)
	if idx == 17:
		PlayerInventory.inventory.erase(17)  # <-- richtig löschen, kein null setzen!
		PlayerInventory._emit_changed()  # UI refresh / signal
		#dgb("Slot 17 erased from inventory ✅")

	if DEBUG:
		_validate_slot(slot)


func left_click_different_item(slot: Node) -> void:
	var ui: Node = _get_ui()
	if ui == null:
		return

	var holding: Variant = ui.get("holding_item")
	if holding == null:
		return

	if able_to_put_into_slot(slot):
		PlayerInventory.set_block_signals(true)
		PlayerInventory.remove_item(slot)
		PlayerInventory.set_block_signals(false)
		PlayerInventory.add_item_to_empty_slot(holding, slot)

		var temp_item: Variant = null
		if _has_property(slot, &"item"):
			temp_item = slot.get("item")

		if slot.has_method("pick_from_slot"):
			#dgb("pick_from_slot")
			slot.call("pick_from_slot")
		else:
			push_error("Slot hat keine pick_from_slot()")
			return

		if temp_item != null and temp_item is Node and is_instance_valid(temp_item as Node):
			(temp_item as Node).global_position = get_global_mouse_position()

		if slot.has_method("put_into_slot"):
			slot.call("put_into_slot", holding)
		else:
			push_error("Slot hat keine put_into_slot()")
			return

		ui.set("holding_item", temp_item)
		if DEBUG:
			_validate_slot(slot)


# gdlint: disable=max-returns
func left_click_same_item(slot: Node) -> void:
	var ui: Node = _get_ui()
	if ui == null:
		return

	var holding: Variant = ui.get("holding_item")
	if holding == null:
		return

	if not _has_property(slot, &"item"):
		push_error("Slot hat keine Property 'item'")
		return

	var slot_item: Variant = slot.get("item")
	if slot_item == null:
		return

	if able_to_put_into_slot(slot):
		if JsonData == null or not _has_property(JsonData, &"item_data"):
			push_error("JsonData.item_data fehlt, StackSize kann nicht gelesen werden!")
			return

		var item_data: Dictionary = JsonData.get("item_data")
		var name: String = str((slot_item as Node).get("item_name"))

		if not item_data.has(name):
			push_error("JsonData.item_data hat kein Item '%s'" % name)
			return
		if (
			not (item_data[name] is Dictionary)
			or not (item_data[name] as Dictionary).has("StackSize")
		):
			push_error("Item '%s' hat keinen StackSize Eintrag" % name)
			return

		var stack_size: int = int((item_data[name] as Dictionary)["StackSize"])
		var slot_qty: int = int((slot_item as Node).get("item_quantity"))
		var holding_qty: int = int((holding as Node).get("item_quantity"))

		var able_to_add: int = stack_size - slot_qty
		if able_to_add <= 0:
			return

		if able_to_add >= holding_qty:
			PlayerInventory.add_item_quantity(slot, holding_qty)
			if (slot_item as Node).has_method("add_item_quantity"):
				(slot_item as Node).call("add_item_quantity", holding_qty)

			(holding as Node).queue_free()
			ui.set("holding_item", null)
		else:
			PlayerInventory.add_item_quantity(slot, able_to_add)
			if (slot_item as Node).has_method("add_item_quantity"):
				(slot_item as Node).call("add_item_quantity", able_to_add)
			if (holding as Node).has_method("decrease_item_quantity"):
				(holding as Node).call("decrease_item_quantity", able_to_add)

		if DEBUG:
			_validate_slot(slot)


# gdlint: enable=max-returns


func left_click_not_holding(slot: Node) -> void:
	var ui: Node = _get_ui()
	if ui == null:
		push_error("UI ist null")
		return

	if not _has_property(slot, &"item"):
		push_error("Slot hat keine Property 'item'")
		return

	var slot_item: Variant = slot.get("item")
	if slot_item == null:
		#dgb("Pick: slot_item ist null")
		return

	#dgb("=== PICK START ===")
	#dgb("Slot index: " + str(slot.get("slot_index")))
	#dgb("Slot item: " + str(slot_item))
	if slot_item is Node:
		var n := slot_item as Node
		#dgb("Item name: " + str(n.get("item_name")))
		#dgb("Item qty : " + str(n.get("item_quantity")))
		#dgb("Item parent BEFORE: " + str(n.get_parent()))
		#dgb("Item in tree BEFORE: " + str(n.is_inside_tree()))
		if n is CanvasItem:
			var ci := n as CanvasItem
			#dgb("Canvas visible BEFORE: " + str(ci.visible))
			#dgb("Canvas z_index BEFORE: " + str(ci.z_index))
			#dgb("Canvas top_level BEFORE: " + str(ci.top_level))
	else:
		push_error("slot_item ist kein Node?? -> " + str(typeof(slot_item)))
		return

	# Inventory-State
	# Inventory-State (wichtig: während Pick Signal blocken)
	PlayerInventory.set_block_signals(true)
	PlayerInventory.remove_item(slot)
	PlayerInventory.set_block_signals(false)

	# UI-State
	ui.set("holding_item", slot_item)
	#dgb("UI holding_item gesetzt: " + str(ui.get("holding_item")))

	# Slot pick
	if slot.has_method("pick_from_slot"):
		slot.call("pick_from_slot")
		#dgb("pick_from_slot() ausgeführt")
	else:
		push_error("Slot hat keine pick_from_slot()")
		return

	# Nach pick prüfen
	if ui.get("holding_item") is Node:
		var hn := ui.get("holding_item") as Node
		#dgb("Holding parent AFTER: " + str(hn.get_parent()))
		#dgb("Holding in tree AFTER: " + str(hn.is_inside_tree()))
		if hn is CanvasItem:
			var hci := hn as CanvasItem
			#dgb("Holding visible AFTER: " + str(hci.visible))
			#dgb("Holding z_index AFTER: " + str(hci.z_index))
			#dgb("Holding top_level AFTER: " + str(hci.top_level))
		#dgb("Holding global pos AFTER: " + str(hn.global_position))
	else:
		push_error("holding_item ist nach pick kein Node / null")

	# Direkt unter Maus setzen
	if slot_item is Node and is_instance_valid(slot_item as Node):
		(slot_item as Node).global_position = get_global_mouse_position()
		#dgb("Holding moved to mouse: " + str((slot_item as Node).global_position))

	#dgb("=== PICK END ===")

	if DEBUG:
		_validate_slot(slot)


# -------------------------
# DEBUG VALIDATION HELPERS
# -------------------------
func _validate_slot(slot: Node) -> void:
	if not _has_property(slot, &"slot_index"):
		push_error("Slot ohne slot_index")
		return

	var idx: int = int(slot.get("slot_index"))

	var inv_has: bool = false
	if PlayerInventory != null and _has_property(PlayerInventory, &"inventory"):
		var inv: Dictionary = PlayerInventory.get("inventory")
		inv_has = inv.has(idx)

	var ui_has: bool = false
	if _has_property(slot, &"item"):
		ui_has = (slot.get("item") != null)

	#dgb("VALIDATE Slot %d: ui_has_item=%s inv_has_item=%s" % [idx, str(ui_has), str(inv_has)])
