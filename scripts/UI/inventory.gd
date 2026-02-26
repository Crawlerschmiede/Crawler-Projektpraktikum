# InventoryUI.gd (Godot 4.x, vollständig typisiert & compile-safe)
# gdlint: disable=max-file-lines

extends Control

signal inventory_changed

const DEBUG: bool = true

# Slot Script (Pfad prüfen!)
const SlotScript: GDScript = preload("res://scripts/UI/Slot.gd")
const ITEM_SCENE: PackedScene = preload("res://scenes/Item/item.tscn")

var _ui: Node = null
var _slot_callables: Dictionary = {}  # key: Node (slot), value: Callable
var _cached_inv_slots: Array = []
var _cached_inv_slots_valid: bool = false
var _inv_slot_nodes_by_index: Dictionary = {}

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

func get_equipment_damage_factor() -> Array:
	var equipment_slots = _get_equipment_slots()
	var damage_factors: Array = []
	for slot in equipment_slots:
		var item_in_slot = slot.get_item()
		if item_in_slot != null:
			var df = item_in_slot.get_damage_factor()
			print("[DMG] slot=", slot.name, " item=", item_in_slot.get("item_name"), " df=", df)
			damage_factors.append(df)
	return damage_factors

func get_equipment_defence_factor() -> Array:
	var equipment_slots = _get_equipment_slots()
	var defence_factors: Array = []

	for slot in equipment_slots:
		var item_in_slot = slot.get_item()
		if item_in_slot != null:
			var df = item_in_slot.get_defence_factor()
			print(
				"[DEF] slot=",
				slot.name,
				" item=",
				item_in_slot.get("item_name"),
				" df=",
				df
			)
			defence_factors.append(df)

	return defence_factors
	
func _is_descendant(parent: Node, child: Node) -> bool:
	# Safe replacement for Engine-specific "is_a_parent_of" across Node types.
	if parent == null or child == null:
		return false
	var p: Node = child.get_parent()
	while p != null:
		if p == parent:
			return true
		p = p.get_parent()
	return false


func _get_all_slots() -> Array[Node]:
	var out: Array[Node] = []
	_collect_slots_recursive(inv_grid, out)
	_collect_slots_recursive(equip_grid, out)
	_collect_slots_recursive(hotbar_grid, out)

	# Include special slots (e.g. SellSlot, CraftSlot, ChestSlot) which might live
	# outside of the regular grid containers but still should be part of the
	# global slot index space. We use groups so scenes can opt-in their nodes.
	if get_tree() != null:
		var special := get_tree().get_nodes_in_group("SellSlot")
		for s in special:
			if s != null and s is Node:
				out.append(s)

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


func get_equipment_range():
	var equipment_slots = _get_equipment_slots()
	var gotten_range = "short"
	for slot in equipment_slots:
		var item_in_slot = slot.get_item()
		if item_in_slot != null:
			gotten_range = slot.get_item().get_range()
	return gotten_range


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

	# Ensure keyboard navigation works for inventory slots (only)
	set_process_unhandled_input(true)

	# When opening inventory, ensure a sensible selected slot
	call_deferred("_ensure_inventory_selection")


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

		# Make slots focusable so grab_focus() works later
		if ctrl != null:
			ctrl.focus_mode = Control.FOCUS_ALL
			# If needed, we could enable recursive focus behavior here.
			# The method expects an enum value in Godot 4, not a bool — skip to avoid type errors.

		# Debug info for this slot

		# Slot properties setzen
		if _has_property(s, &"slot_index"):
			s.set("slot_index", i)
			# keep quick reference to inventory slot nodes by their index
			# for fast lookup
			if s.is_in_group("Inventory"):
				_inv_slot_nodes_by_index[int(i)] = s
		else:
			push_error(
				(
					"Slot %d hat keine Property 'slot_index'"
					+ " (in Slot.gd: @export var slot_index:int)" % i
				)
			)

		if _has_property(s, &"slot_type"):
			# Respect designer-configured slot_type when present — do not overwrite.
			var cur_type := int(s.get("slot_type"))

		else:
			# Determine slot_type from groups or parent container when property is missing
			var assigned_type = SlotScript.SlotType.INVENTORY
			if s.is_in_group("Inventory"):
				assigned_type = SlotScript.SlotType.INVENTORY
			elif hotbar_grid != null and _is_descendant(hotbar_grid, s):
				assigned_type = SlotScript.SlotType.HOTBAR

			# set property on slot so downstream logic sees a proper type
			s.set("slot_type", assigned_type)

	# Invalidate cached slot list after setup
	_rebuild_cached_inventory_slots()


func _connect_inventory_signal() -> void:
	if PlayerInventory != null and PlayerInventory.has_signal("inventory_changed"):
		var cb: Callable = Callable(self, "_on_inventory_changed")
		# connect using Callable (Godot 4 compatible)
		# and avoid double-connections
		if not PlayerInventory.inventory_changed.is_connected(cb):
			PlayerInventory.inventory_changed.connect(cb)


func _invalidate_cached_inventory_slots() -> void:
	_cached_inv_slots_valid = false
	# keep _inv_slot_nodes_by_index entries; if necessary,
	# it can be rebuilt in _rebuild_cached_inventory_slots
	# (we avoid clearing to preserve references)


func _rebuild_cached_inventory_slots() -> void:
	# Build ordered array of inventory slot Nodes from the index->node map.
	# This avoids sorting by properties
	var out: Array = []
	if _inv_slot_nodes_by_index.size() == 0:
		# fallback: build map dynamically if not present
		var all: Array = _get_slots()
		for s in all:
			if (
				s is Node
				and s.is_in_group("Inventory")
				and is_instance_valid(s)
				and _has_property(s, &"slot_index")
			):
				var idx := int(s.get("slot_index"))
				_inv_slot_nodes_by_index[idx] = s

	var keys: Array = _inv_slot_nodes_by_index.keys()
	# numeric sort
	keys.sort_custom(
		func(a, b):
			var ai := int(a)
			var bi := int(b)
			if ai < bi:
				return -1
			if ai > bi:
				return 1
			return 0
	)

	for k in keys:
		var n = _inv_slot_nodes_by_index.get(k, null)
		if n != null and is_instance_valid(n):
			out.append(n)

	_cached_inv_slots = out
	_cached_inv_slots_valid = true


func _on_inventory_changed() -> void:
	_invalidate_cached_inventory_slots()
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
		print("Slot size: ", slots.size())
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

	# Ensure selected slot is visible / styled after rebuild
	_ensure_inventory_selection()


# -------------------------
# INPUT / DRAG HANDLING
# -------------------------
func slot_gui_input(event: InputEvent, slot: Node) -> void:
	#dgb("CLICK on slot " + str(slot.get("slot_index")))
	if not (event is InputEventMouseButton):
		return

	var mbe: InputEventMouseButton = event as InputEventMouseButton
	# only care about pressed mouse button events
	if not mbe.pressed:
		return

	# Right-click special: if player is holding an item, allow placing it into the slot
	if mbe.button_index == MOUSE_BUTTON_RIGHT:
		# place a single unit on right-click (or fallback to existing swap behavior)
		right_click_put_one_unit(slot)
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

	# noop

	PlayerInventory.inventory.erase(17)

	if holding is Node and is_instance_valid(holding as Node):
		var hn := holding as Node
		hn.global_position = get_global_mouse_position()


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

	# noop

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


func right_click_put_one_unit(slot: Node) -> void:
	# Place exactly one unit from the holding item into `slot`. If holding has only one
	# unit we fall back to the full-place behavior so ownership of the node moves.
	var ui: Node = _get_ui()
	if ui == null or not _has_property(ui, &"holding_item"):
		return
	var holding: Variant = ui.get("holding_item")
	if holding == null or not (holding is Node):
		return
	var hnode: Node = holding as Node
	var holding_name: String = str(hnode.get("item_name"))
	var holding_qty: int = int(hnode.get("item_quantity"))

	var slot_item: Variant = null
	if _has_property(slot, &"item"):
		slot_item = slot.get("item")

	# empty slot: put one unit
	if slot_item == null:
		if holding_qty <= 1:
			# just put the whole item (node moves)
			left_click_empty_slot(slot)
		else:
			# create a new visual item node with qty 1
			var new_item = ITEM_SCENE.instantiate()
			var can_place := true
			if new_item == null:
				push_error("Failed to instantiate ITEM_SCENE")
				can_place = false
			elif not new_item.has_method("set_item"):
				push_error("Instantiated item has no set_item()")
				can_place = false
			else:
				new_item.call("set_item", holding_name, 1)

			if can_place:
				# attempt to add to backend
				var ok: bool = false
				if (
					typeof(PlayerInventory) != TYPE_NIL
					and PlayerInventory != null
					and PlayerInventory.has_method("add_item_to_empty_slot")
				):
					ok = PlayerInventory.add_item_to_empty_slot(new_item, slot)
				if not ok:
					# cleanup and bail
					if is_instance_valid(new_item):
						new_item.queue_free()
				else:
					# attach to UI
					if slot.has_method("put_into_slot"):
						slot.call("put_into_slot", new_item)
					else:
						push_error("Slot hat keine put_into_slot()")

					# decrease holding quantity by 1
					if hnode.has_method("decrease_item_quantity"):
						hnode.call("decrease_item_quantity", 1)
					else:
						# best-effort: adjust property
						var curq := int(hnode.get("item_quantity"))
						hnode.set("item_quantity", max(0, curq - 1))

					# if holding depleted, free and clear
					if int(hnode.get("item_quantity")) <= 0:
						if is_instance_valid(hnode):
							hnode.queue_free()
						ui.set("holding_item", null)
					if DEBUG:
						_validate_slot(slot)

	# slot contains an item
	# same item -> add one to stack
	elif slot_item is Node and is_instance_valid(slot_item as Node):
		var sitem := slot_item as Node
		var slot_name := str(sitem.get("item_name"))
		if slot_name == holding_name:
			# add to backend
			if (
				typeof(PlayerInventory) != TYPE_NIL
				and PlayerInventory != null
				and PlayerInventory.has_method("add_item_quantity")
			):
				PlayerInventory.add_item_quantity(slot, 1)
			# update visual
			if sitem.has_method("add_item_quantity"):
				sitem.call("add_item_quantity", 1)
			# decrease holding
			if hnode.has_method("decrease_item_quantity"):
				hnode.call("decrease_item_quantity", 1)
			else:
				var curq2 := int(hnode.get("item_quantity"))
				hnode.set("item_quantity", max(0, curq2 - 1))
			# if holding depleted, free and clear
			if int(hnode.get("item_quantity")) <= 0:
				if is_instance_valid(hnode):
					hnode.queue_free()
				ui.set("holding_item", null)
			if DEBUG:
				_validate_slot(slot)
		else:
			# different item -> fallback to full swap behavior
			left_click_different_item(slot)


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


func verify_equipment_slots() -> Array:
	# Collect all slot-like nodes under the equipment container and print a validation summary.
	var out: Array[Node] = []
	_collect_slots_recursive(inv_grid, out)

	var results: Array = []
	for s in out:
		var info := {}
		info["node_name"] = s.name
		# slot_index
		if _has_property(s, &"slot_index"):
			info["slot_index"] = int(s.get("slot_index"))
		else:
			info["slot_index"] = null
		# slot_type
		if _has_property(s, &"slot_type"):
			info["slot_type"] = int(s.get("slot_type"))
		else:
			info["slot_type"] = null
		# groups
		info["groups"] = s.get_groups()
		# API methods
		info["has_initialize_item"] = s.has_method("initialize_item")
		info["has_put_into_slot"] = s.has_method("put_into_slot")
		info["has_pick_from_slot"] = s.has_method("pick_from_slot")
		# item presence (if PlayerInventory has inventory data)
		var item_present := false
		if (
			_has_property(s, &"slot_index")
			and PlayerInventory != null
			and _has_property(PlayerInventory, &"inventory")
		):
			var idx := int(s.get("slot_index"))
			var inv = PlayerInventory.get("inventory")
			if inv.has(idx) and inv[idx] != null:
				item_present = true
		info["item_present"] = item_present

		results.append(info)

	return results


##############################
# Keyboard selection helpers
##############################
func _get_inventory_slot_nodes_sorted() -> Array:
	# return cached result when valid
	if _cached_inv_slots_valid:
		return _cached_inv_slots

	# rebuild cache from index->node map (fast)
	_rebuild_cached_inventory_slots()
	return _cached_inv_slots


func _ensure_inventory_selection() -> void:
	var inv_slots: Array = _get_inventory_slot_nodes_sorted()

	if inv_slots.size() == 0:
		return

	var cur := PlayerInventory.get_selected_slot()
	var found := false
	for s in inv_slots:
		if int(s.get("slot_index")) == int(cur):
			found = true
			break

	if not found:
		# choose first inventory slot as default
		var def_idx := int(inv_slots[0].get("slot_index"))

		if PlayerInventory.has_method("set_selectet_slot"):
			PlayerInventory.set_selectet_slot(def_idx)
		else:
			PlayerInventory.selected_slot = def_idx

	# refresh styles so selected state shows
	for s in _get_slots():
		if s.has_method("refresh_style"):
			s.call("refresh_style")


func _move_inventory_selection(delta: int) -> void:
	var t0 := 0
	var inv_slots: Array = _get_inventory_slot_nodes_sorted()
	if inv_slots.size() == 0:
		return

	# Filter out any freed/null nodes so we don't call methods on them.
	var slots: Array = []
	for s in inv_slots:
		if s != null and is_instance_valid(s) and _has_property(s, &"slot_index"):
			slots.append(s)

	if slots.size() == 0:
		return

	var cur := int(PlayerInventory.get_selected_slot())

	var idx := -1
	for i in range(slots.size()):
		if int(slots[i].get("slot_index")) == cur:
			idx = i
			break

	if idx == -1:
		# not found -> place at either end depending on direction
		if delta > 0:
			idx = 0
		else:
			idx = slots.size() - 1

	var new_idx = clamp(idx + delta, 0, slots.size() - 1)

	var new_slot_node: Node = slots[new_idx]
	var new_slot_index: int = int(new_slot_node.get("slot_index"))

	# determine previous node (if any) so we can refresh only the two affected slots
	var prev_node: Node = null
	if idx >= 0 and idx < slots.size():
		prev_node = slots[idx]

	if PlayerInventory.has_method("set_selectet_slot"):
		PlayerInventory.set_selectet_slot(new_slot_index)
	else:
		PlayerInventory.selected_slot = new_slot_index

	# refresh visuals only for previous and new slot to reduce cost
	if is_instance_valid(prev_node) and prev_node.has_method("refresh_style"):
		prev_node.call("refresh_style")

	if is_instance_valid(new_slot_node) and new_slot_node.has_method("refresh_style"):
		new_slot_node.call("refresh_style")

	# try to give focus to the newly selected control so keyboard nav is visible
	if new_slot_node is Control:
		(new_slot_node as Control).grab_focus()


func _get_hotbar_slot_nodes_sorted() -> Array:
	var out: Array[Node] = []
	_collect_slots_recursive(hotbar_grid, out)
	# Keep visual order as in scene tree (children order)
	out.sort_custom(
		func(a, b):
			# If both have slot_index, sort by it
			var ai := -1
			var bi := -1
			if a.has_method("get"):
				ai = int(a.get("slot_index"))
			if b.has_method("get"):
				bi = int(b.get("slot_index"))
			if ai < bi:
				return -1
			if ai > bi:
				return 1
			return 0
	)
	return out


func _swap_inventory_with_hotbar(hotbar_number: int) -> void:
	# hotbar_number is 1-based index (1..n)
	var hotbar_nodes: Array = _get_hotbar_slot_nodes_sorted()
	if hotbar_number < 1 or hotbar_number > hotbar_nodes.size():
		return

	var hot_node: Node = hotbar_nodes[hotbar_number - 1]
	if hot_node == null:
		return

	var inv_idx: int = int(PlayerInventory.get_selected_slot())
	var hot_idx: int = -1
	if hot_node.has_method("get"):
		hot_idx = int(hot_node.get("slot_index"))
	else:
		return

	if inv_idx < 0 or hot_idx < 0:
		return

	_swap_slots_by_index(inv_idx, hot_idx)


func _swap_slots_by_index(a_idx: int, b_idx: int) -> void:
	if PlayerInventory == null or not _has_property(PlayerInventory, &"inventory"):
		return
	var inv: Dictionary = PlayerInventory.get("inventory")
	var a = inv.get(a_idx, null)
	var b = inv.get(b_idx, null)

	# Nothing to do
	if a == null and b == null:
		return

	# Swap logic
	if b == null:
		inv[b_idx] = a
		inv.erase(a_idx)
	elif a == null:
		inv[a_idx] = b
		inv.erase(b_idx)
	else:
		inv[a_idx] = b
		inv[b_idx] = a

	# Notify PlayerInventory to refresh UI
	if PlayerInventory.has_method("_emit_changed"):
		PlayerInventory._emit_changed()
	else:
		PlayerInventory.inventory = PlayerInventory.get("inventory")

	# Refresh visuals
	for s in _get_slots():
		if s.has_method("refresh_style"):
			s.call("refresh_style")

	# invalidate cached inventory slots so selection/sorting uses fresh data
	_invalidate_cached_inventory_slots()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	var key := event as InputEventKey

	var handled := false

	# -------------------
	# Hotbar swap (1..5)
	# -------------------
	if key.unicode >= 49 and key.unicode <= 53:
		var num := key.unicode - 48
		var hotbar_count := _get_hotbar_slot_nodes_sorted().size()
		var mapped = clamp(hotbar_count - num + 1, 1, hotbar_count)
		_swap_inventory_with_hotbar(mapped)
		handled = true
	elif key.is_action_pressed("ui_left"):
		# -------------------
		# Inventory navigation
		# -------------------
		_move_inventory_selection(1)
		handled = true
	elif key.is_action_pressed("ui_right"):
		_move_inventory_selection(-1)
		handled = true
	elif key.is_action_pressed("ui_up"):
		var cols: int = inv_grid.columns if inv_grid != null else 0
		_move_inventory_selection(cols if cols > 0 else 1)
		handled = true
	elif key.is_action_pressed("ui_down"):
		var cols: int = inv_grid.columns if inv_grid != null else 0
		_move_inventory_selection(-cols if cols > 0 else -1)
		handled = true
	elif key.is_action_pressed("ui_accept"):
		# -------------------
		# Equip with Enter
		# -------------------
		var can_equip := true
		var cl2 := $"../../CanvasLayer2"
		if cl2 != null and cl2.visible:
			can_equip = false

		var sel_idx := int(PlayerInventory.get_selected_slot())
		if sel_idx < 0:
			can_equip = false

		var inv: Dictionary = PlayerInventory.inventory
		var data = inv.get(sel_idx)
		if data == null:
			can_equip = false

		var item_name: String = ""
		if can_equip:
			item_name = data[0]

		var item_group = (
			PlayerInventory._get_item_group(item_name)
			if PlayerInventory.has_method("_get_item_group")
			else null
		)
		if item_group == null:
			can_equip = false

		if can_equip:
			var chosen_idx := -1
			for s in _get_slots():
				if not _has_property(s, &"slot_index"):
					continue

				var tidx := int(s.get("slot_index"))

				# equipment range only
				if tidx < 0 or tidx > 6:
					continue

				# group match only
				if not s.is_in_group(item_group):
					continue

				if not inv.has(tidx):
					chosen_idx = tidx
					break

				if chosen_idx == -1:
					chosen_idx = tidx

			if chosen_idx >= 0:
				_swap_slots_by_index(sel_idx, chosen_idx)
				handled = true

	if handled:
		accept_event()
