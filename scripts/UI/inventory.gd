# InventoryUI.gd (Godot 4.x, vollständig typisiert & compile-safe)

extends Control

signal inventory_changed

const DEBUG: bool = false

# Slot Script (Pfad prüfen!)
const SlotScript: GDScript = preload("res://scripts/UI/Slot.gd")
const ITEM_SCENE: PackedScene = preload("res://scenes/Item/item.tscn")
const InventoryStoreAdapterScript: GDScript = preload("res://scripts/UI/inventory_store_adapter.gd")
const InventoryRendererScript: GDScript = preload("res://scripts/UI/inventory_renderer.gd")
const InventoryInteractionScript: GDScript = preload("res://scripts/UI/inventory_interaction.gd")
const InventorySelectionScript: GDScript = preload("res://scripts/UI/inventory_selection.gd")
const InventorySelectionCallbacksScript: GDScript = preload(
	"res://scripts/UI/inventory_selection_callbacks.gd"
)

var _ui: Node = null
var _slot_callables: Dictionary = {}  # key: Node (slot), value: Callable
var _cached_inv_slots: Array = []
var _cached_inv_slots_valid: bool = false
var _inv_slot_nodes_by_index: Dictionary = {}
var _store_adapter: InventoryStoreAdapter = null
var _inventory_renderer: InventoryRenderer = null
var _interaction: InventoryInteraction = null
var _selection: InventorySelection = null

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
	return slots


func get_equipment_skills():
	var equipment_slots = _get_equipment_slots()
	var gotten_skills = []
	for slot in equipment_slots:
		var item_in_slot = slot.get_item()
		if item_in_slot != null:
			var bound = item_in_slot.get_bound_skills()
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
			gotten_range = item_in_slot.get_range()
	return gotten_range


# -------------------------
# Lifecycle
# -------------------------
func _ready() -> void:
	#dgb("_ready() gestartet")
	_initialize_dependencies()

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


func _initialize_dependencies() -> void:
	if _store_adapter == null:
		_store_adapter = InventoryStoreAdapterScript.new(PlayerInventory, JsonData)

	if _inventory_renderer == null:
		_inventory_renderer = InventoryRendererScript.new(
			_store_adapter,
			Callable(self, "_get_slots"),
			Callable(self, "_get_holding_item_for_render"),
			Callable(self, "_ensure_inventory_selection")
		)

	if _interaction == null:
		_interaction = InventoryInteractionScript.new(
			_store_adapter,
			ITEM_SCENE,
			DEBUG,
			Callable(self, "_get_ui"),
			Callable(self, "get_global_mouse_position"),
			Callable(self, "_validate_slot")
		)

	if _selection == null:
		var callbacks: InventorySelectionCallbacks = InventorySelectionCallbacksScript.new()
		callbacks.get_inventory_slots = Callable(self, "_get_inventory_slot_nodes_sorted")
		callbacks.refresh_slot_style = Callable(self, "_refresh_slot_style")
		callbacks.refresh_all_styles = Callable(self, "_refresh_all_slot_styles")
		callbacks.swap_slots = Callable(self, "_swap_slots_by_index")
		callbacks.get_hotbar_slots = Callable(self, "_get_hotbar_slot_nodes_sorted")
		callbacks.get_slots = Callable(self, "_get_slots")
		callbacks.is_equip_blocked = Callable(self, "_is_equip_blocked")

		_selection = InventorySelectionScript.new(_store_adapter, callbacks)


func _get_holding_item_for_render() -> Node:
	var ui := _get_ui()
	if ui == null or not InventoryUtils.has_property(ui, &"holding_item"):
		return null
	var hv: Variant = ui.get("holding_item")
	if hv is Node and is_instance_valid(hv as Node):
		return hv as Node
	return null


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
		if _store_adapter == null:
			push_error("InventoryStoreAdapter ist null")
			continue
		_store_adapter.register_slot_index(i, groups)

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
		if InventoryUtils.has_property(s, &"slot_index"):
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

		if InventoryUtils.has_property(s, &"slot_type"):
			# Respect designer-configured slot_type when present — do not overwrite.
			pass

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
	if _store_adapter == null:
		push_error("InventoryStoreAdapter ist null")
		return

	if not _store_adapter.connect_inventory_changed(self, &"_on_inventory_changed"):
		push_error("Inventory konnte nicht mit inventory_changed verbunden werden")


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
				and InventoryUtils.has_property(s, &"slot_index")
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
	if _inventory_renderer == null:
		_initialize_dependencies()

	if _inventory_renderer != null:
		_inventory_renderer.render()
		return

	push_error("InventoryRenderer konnte nicht initialisiert werden")


# -------------------------
# INPUT / DRAG HANDLING
# -------------------------
func slot_gui_input(event: InputEvent, slot: Node) -> void:
	if _interaction == null:
		_initialize_dependencies()
	if _interaction != null:
		_interaction.handle_slot_gui_input(event, slot)


func _process(_delta: float) -> void:
	var ui: Node = _get_ui()
	if ui == null:
		return
	if not InventoryUtils.has_property(ui, &"holding_item"):
		return

	var holding: Variant = ui.get("holding_item")
	if holding == null:
		return

	if holding is Node and is_instance_valid(holding as Node):
		var hn := holding as Node
		hn.global_position = get_global_mouse_position()


func _refresh_slot_style(slot: Node) -> void:
	if _inventory_renderer == null:
		_initialize_dependencies()
	if _inventory_renderer != null:
		_inventory_renderer.refresh_slot_style(slot)


func _refresh_all_slot_styles() -> void:
	if _inventory_renderer == null:
		_initialize_dependencies()
	if _inventory_renderer != null:
		_inventory_renderer.refresh_all_slot_styles(_get_slots())


# -------------------------
# DEBUG VALIDATION HELPERS
# -------------------------
func _validate_slot(slot: Node) -> void:
	if not InventoryUtils.has_property(slot, &"slot_index"):
		push_error("Slot ohne slot_index")
		return

	var idx: int = int(slot.get("slot_index"))

	var inv_has: bool = false
	if PlayerInventory != null and InventoryUtils.has_property(PlayerInventory, &"inventory"):
		var inv: Dictionary = PlayerInventory.get("inventory")
		inv_has = inv.has(idx)

	var ui_has: bool = false
	if InventoryUtils.has_property(slot, &"item"):
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
		if InventoryUtils.has_property(s, &"slot_index"):
			info["slot_index"] = int(s.get("slot_index"))
		else:
			info["slot_index"] = null
		# slot_type
		if InventoryUtils.has_property(s, &"slot_type"):
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
			InventoryUtils.has_property(s, &"slot_index")
			and PlayerInventory != null
			and InventoryUtils.has_property(PlayerInventory, &"inventory")
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
	if _selection == null:
		_initialize_dependencies()
	if _selection != null:
		_selection.ensure_inventory_selection()


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


func _swap_slots_by_index(a_idx: int, b_idx: int) -> void:
	if _store_adapter == null:
		push_error("InventoryStoreAdapter ist null")
		return

	var changed := _store_adapter.swap_slots_by_index(a_idx, b_idx)

	if changed:
		_refresh_all_slot_styles()

	# invalidate cached inventory slots so selection/sorting uses fresh data
	_invalidate_cached_inventory_slots()


func _is_equip_blocked() -> bool:
	var cl2 := $"../../CanvasLayer2"
	return cl2 != null and cl2.visible


func _unhandled_input(event: InputEvent) -> void:
	if _selection == null:
		_initialize_dependencies()

	var cols: int = inv_grid.columns if inv_grid != null else 0
	var handled := false
	if _selection != null:
		handled = _selection.handle_unhandled_input(event, cols)

	if handled:
		accept_event()
