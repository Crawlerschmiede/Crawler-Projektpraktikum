extends Control

const DEBUG := true
func dbg(msg: String) -> void:
	if DEBUG:
		print("[Inventory] ", msg)

# Slot Script (Pfad prüfen!)
const SlotScript := preload("res://scenes/Slot.gd")

@onready var inventory_slots: GridContainer = $GridContainer


func _ready() -> void:
	dbg("_ready() gestartet")

	# Sicherheitscheck: GridContainer vorhanden?
	if inventory_slots == null:
		push_error("GridContainer nicht gefunden: Prüfe den Node-Pfad $GridContainer")
		return

	var slots := inventory_slots.get_children()
	dbg("Slots im GridContainer gefunden: %d" % slots.size())

	if slots.size() == 0:
		push_error("Keine Slots im GridContainer! Hast du Slot Panels als Children drin?")
		return

	# Slot Setup
	for i in range(slots.size()):
		var s := slots[i]

		# Debug: Node typ check
		if not (s is Control):
			push_error("Slot %d ist kein Control! gui_input funktioniert nur bei Control-Nodes." % i)
			continue

		# Ein Slot muss dieses Script/Properties haben
		if not s.has_method("initialize_item"):
			push_error("Slot %d hat keine Methode initialize_item(). Slot.gd fehlt?" % i)

		if not s.has_method("refresh_style"):
			dbg("Slot %d hat keine refresh_style() (optional, aber empfohlen)" % i)

		# Signal connect: doppelte Verbindungen verhindern
		if not s.gui_input.is_connected(slot_gui_input.bind(s)):
			s.gui_input.connect(slot_gui_input.bind(s))

		# slot properties setzen
		# (Nur wenn Property existiert)
		if "slot_index" in s:
			s.slot_index = i
		else:
			push_error("Slot %d hat keine Property slot_index" % i)

		if "slotType" in s:
			s.slotType = SlotScript.SlotType.INVENTORY
		else:
			push_error("Slot %d hat keine Property slotType" % i)

	# Optional: Live Refresh per Signal (sehr empfohlen)
	if PlayerInventory.has_signal("inventory_changed"):
		if not PlayerInventory.inventory_changed.is_connected(_on_inventory_changed):
			PlayerInventory.inventory_changed.connect(_on_inventory_changed)
			dbg("inventory_changed Signal verbunden ✅")
	else:
		dbg("PlayerInventory hat kein Signal inventory_changed (optional)")

	initialize_inventory()


func _on_inventory_changed() -> void:
	dbg("inventory_changed -> initialize_inventory()")
	initialize_inventory()


func initialize_inventory() -> void:
	dbg("initialize_inventory()")

	# Sicherheitscheck: Inventory Dictionary
	if PlayerInventory == null:
		push_error("PlayerInventory ist null – Autoload fehlt?")
		return

	if not ("inventory" in PlayerInventory):
		push_error("PlayerInventory hat keine Variable inventory")
		return

	var slots := inventory_slots.get_children()

	# 1) Erstmal alle Slots leeren / refreshen (Bugfix)
	for i in range(slots.size()):
		var s := slots[i]

		# Falls Slot eine clear Funktion hat – super
		if s.has_method("clear_slot"):
			s.clear_slot()
		else:
			# Wenn nicht: item entfernen, wenn vorhanden
			if "item" in s and s.item != null:
				if is_instance_valid(s.item):
					s.item.queue_free()
				s.item = null

		if s.has_method("refresh_style"):
			s.refresh_style()

	# 2) Dann Inventory Daten neu reinbauen
	var keys := PlayerInventory.inventory.keys()
	dbg("PlayerInventory.inventory keys: %s" % str(keys))

	for slot_index in keys:
		# Schutz: slot_index muss im Slot-Bereich liegen
		if slot_index < 0 or slot_index >= slots.size():
			push_error("Inventory enthält slot_index %s, aber UI hat nur %d Slots"
				% [str(slot_index), slots.size()])
			continue

		var slot := slots[slot_index]
		var data = PlayerInventory.inventory[slot_index]

		# data muss [name, qty] sein
		if typeof(data) != TYPE_ARRAY or data.size() < 2:
			push_error("Ungültige Inventory Daten in Slot %d: %s" % [slot_index, str(data)])
			continue

		var item_name := str(data[0])
		var item_qty := int(data[1])

		dbg("Slot %d <- %s x%d" % [slot_index, item_name, item_qty])

		if slot.has_method("initialize_item"):
			slot.initialize_item(item_name, item_qty)
		else:
			push_error("Slot %d hat initialize_item() nicht – Item kann nicht angezeigt werden" % slot_index)


# -------------------------
# INPUT / DRAG HANDLING
# -------------------------
func slot_gui_input(event: InputEvent, slot: Node) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var ui := find_parent("UserInterface")
			if ui == null:
				push_error("UserInterface Parent nicht gefunden. Node muss so heißen.")
				return

			if not ("holding_item" in ui):
				push_error("UserInterface hat keine Variable holding_item")
				return

			if ui.holding_item != null:
				if not slot.item:
					left_click_empty_slot(slot)
				else:
					if ui.holding_item.item_name != slot.item.item_name:
						left_click_different_item(slot)
					else:
						left_click_same_item(slot)
			elif slot.item:
				left_click_not_holding(slot)


func _process(_delta: float) -> void:
	var ui := find_parent("UserInterface")
	if ui and ui.holding_item:
		ui.holding_item.global_position = get_global_mouse_position()


func able_to_put_into_slot(_slot: Node) -> bool:
	# aktuell immer true bei dir
	return true


func left_click_empty_slot(slot: Node) -> void:
	var ui := find_parent("UserInterface")
	if ui == null:
		return

	if able_to_put_into_slot(slot):
		PlayerInventory.add_item_to_empty_slot(ui.holding_item, slot)
		slot.putIntoSlot(ui.holding_item)
		ui.holding_item = null

		if DEBUG: _validate_slot(slot)


func left_click_different_item(slot: Node) -> void:
	var ui := find_parent("UserInterface")
	if ui == null:
		return

	if able_to_put_into_slot(slot):
		PlayerInventory.remove_item(slot)
		PlayerInventory.add_item_to_empty_slot(ui.holding_item, slot)

		var temp_item = slot.item
		slot.pickFromSlot()

		temp_item.global_position = get_global_mouse_position()

		slot.putIntoSlot(ui.holding_item)
		ui.holding_item = temp_item

		if DEBUG: _validate_slot(slot)


func left_click_same_item(slot: Node) -> void:
	var ui := find_parent("UserInterface")
	if ui == null:
		return

	if able_to_put_into_slot(slot):
		if JsonData == null or not ("item_data" in JsonData):
			push_error("JsonData.item_data fehlt, StackSize kann nicht gelesen werden!")
			return

		var stack_size := int(JsonData.item_data[slot.item.item_name]["StackSize"])
		var able_to_add :int = stack_size - slot.item.item_quantity

		if able_to_add >= ui.holding_item.item_quantity:
			PlayerInventory.add_item_quantity(slot, ui.holding_item.item_quantity)
			slot.item.add_item_quantity(ui.holding_item.item_quantity)

			ui.holding_item.queue_free()
			ui.holding_item = null
		else:
			PlayerInventory.add_item_quantity(slot, able_to_add)
			slot.item.add_item_quantity(able_to_add)
			ui.holding_item.decrease_item_quantity(able_to_add)

		if DEBUG: _validate_slot(slot)


func left_click_not_holding(slot: Node) -> void:
	var ui := find_parent("UserInterface")
	if ui == null:
		return

	PlayerInventory.remove_item(slot)
	ui.holding_item = slot.item
	slot.pickFromSlot()
	ui.holding_item.global_position = get_global_mouse_position()

	if DEBUG: _validate_slot(slot)


# -------------------------
# DEBUG VALIDATION HELPERS
# -------------------------
func _validate_slot(slot: Node) -> void:
	# Damit erkennst du sofort, ob was komisch ist
	if not ("slot_index" in slot):
		push_error("Slot ohne slot_index")
		return

	var idx := int(slot.slot_index)
	var in_inv := PlayerInventory.inventory.has(idx)

	dbg("VALIDATE Slot %d: ui_has_item=%s inv_has_item=%s"
		% [idx, str(slot.item != null), str(in_inv)])
