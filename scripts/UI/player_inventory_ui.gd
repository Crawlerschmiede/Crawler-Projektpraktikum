extends CanvasLayer

var holding_item = null
var current_merchant: Node = null
var merchant_in_range: bool = false

@onready var hot_container := $Inventory/Hotbar/HotContainer
@onready var equipment := $Inventory/Inner/Equiptment
@onready var equipmentlabel := $Inventory/Inner/EquiptmentLabel
@onready var player := $".."
@onready
var merchantgui := $Inventory/Inner/MerchantContainer/HBoxContainer2/HBoxContainer/VBoxContainer
@onready var merchantgui_merchant_container := $Inventory/Inner/MerchantContainer
@onready var coin_screen = $Inventory/coin_sum


func _enable_merchant_ui():
	merchantgui_merchant_container.visible = true
	_set_mouse_filter_recursive(merchantgui_merchant_container, Control.MOUSE_FILTER_STOP)

	equipment.visible = false
	equipmentlabel.visible = false


func _disable_merchant_ui():
	merchantgui_merchant_container.visible = false
	_set_mouse_filter_recursive(merchantgui_merchant_container, Control.MOUSE_FILTER_IGNORE)

	equipment.visible = true
	equipmentlabel.visible = true


#func force_toggle_inventory():
## This is exactly the logic inside your _input
#_disable_merchant_ui()
#$Inventory/Inner.visible = !$Inventory/Inner.visible
#if $Inventory/Inner.visible:
#$Inventory/Inner/InventoryLabel/Label.text = "Inventory"


func _input(event):
	if event.is_action_pressed("open_inventory"):
		# If merchant UI is currently shown, close it and ensure the
		# normal inventory remains visible (swap behaviour).
		if merchantgui_merchant_container.visible:
			# merchant UI open -> swap to normal inventory
			_disable_merchant_ui()
			$Inventory/Inner.visible = true
			$Inventory/Inner/InventoryLabel/Label.text = "Inventory"
		else:
			# Normal toggle when no merchant UI is active
			_disable_merchant_ui()
			$Inventory/Inner.visible = !$Inventory/Inner.visible
			if $Inventory/Inner.visible:
				$Inventory/Inner/InventoryLabel/Label.text = "Inventory"

	# Hotbar keys (1..5)
	for i in range(1, 6):
		if Input.is_action_just_pressed("hotbar_slot%d" % i) and not $Inventory/Inner.visible:
			var slot_index := i + 17
			PlayerInventory.set_selectet_slot(slot_index)
			_refresh_hotbar_styles()
			return

	# Merchant / Inventory quick keys handled by actions
	if Input.is_action_just_pressed("merchant_open"):
		# If merchant UI is open, allow closing it regardless of range.
		if merchantgui_merchant_container.visible:
			_disable_merchant_ui()
			# close merchant UI and hide the whole inventory (do not switch to normal inventory)
			$Inventory/Inner/InventoryLabel/Label.text = "Inventory"
			$Inventory/Inner.visible = false
			return
		# Otherwise open merchant UI only when in range
		if merchant_in_range:
			_enable_merchant_ui()
			$Inventory/Inner.visible = true
			$Inventory/Inner/InventoryLabel/Label.text = "Merchant"
			return

	# Note: 'open_inventory' handling moved earlier to toggle inventory and
	# disable merchant UI when appropriate. Removed duplicate handling.


func _refresh_hotbar_styles() -> void:
	# refresht ALLE Slot-Nodes im HotContainer
	for child in hot_container.get_children():
		if child is Slot:
			child.refresh_style()


func _ready() -> void:
	# Connect coin display to PlayerInventory changes
	_disable_merchant_ui()
	$Inventory/Inner.visible = false

	if (
		typeof(PlayerInventory) != TYPE_NIL
		and PlayerInventory != null
		and PlayerInventory.has_signal("inventory_changed")
	):
		var cb: Callable = Callable(self, "_update_coin_screen")
		if not PlayerInventory.inventory_changed.is_connected(cb):
			PlayerInventory.inventory_changed.connect(cb)

	# Initial update
	_update_coin_screen()

	# Ensure runtime input actions exist: 'merchant_open' (R) and add 'e' to 'open_inventory'
	if not InputMap.has_action("merchant_open"):
		InputMap.add_action("merchant_open")
		var ev_r := InputEventKey.new()
		ev_r.unicode = 114  # 'r'
		InputMap.action_add_event("merchant_open", ev_r)

	# Ensure 'open_inventory' exists and contains 'e' as a binding (safe to add duplicate)
	if not InputMap.has_action("open_inventory"):
		InputMap.add_action("open_inventory")
	var ev_e := InputEventKey.new()
	ev_e.unicode = 101  # 'e'
	InputMap.action_add_event("open_inventory", ev_e)

	# Connect existing merchants (if any)
	for m in get_tree().get_nodes_in_group("merchant_entity"):
		#print("CONNECT MERCHANT:", m)
		var cb2: Callable = Callable(self, "_on_merchant_open")
		if not m.player_entered_merchant.is_connected(cb2):
			m.player_entered_merchant.connect(cb2)

		# connect left signal as well
		var cb_left: Callable = Callable(self, "_on_merchant_left")
		if (
			m.has_signal("player_left_merchant")
			and not m.player_left_merchant.is_connected(cb_left)
		):
			m.player_left_merchant.connect(cb_left)

	# Watch for merchants that are added later
	if not get_tree().has_signal("node_added"):
		# older engine versions may differ; skip if not available
		return
	get_tree().node_added.connect(Callable(self, "_on_node_added"))


func _update_coin_screen() -> void:
	$Inventory/coin_sum.initialize_item("coin", PlayerInventory.coins)


func _on_merchant_open(entity, data):
	# remember which merchant we're interacting with
	current_merchant = entity
	merchant_in_range = true
	_enable_merchant_ui()

	# Diagnostics: ensure data contains items
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("_on_merchant_open: data is not a Dictionary: %s" % [str(data)])
	else:
		if not data.has("items"):
			push_warning("_on_merchant_open: data has no 'items' key: %s" % [str(data)])
		else:
			var cnt := int(data["items"].size()) if data["items"] != null else 0
			push_warning("_on_merchant_open: opening merchant with %d items" % cnt)

	# ensure merchantgui has expected method
	if not merchantgui.has_method("show_merchant"):
		push_warning("merchantgui has no method 'show_merchant' (node: %s)" % [str(merchantgui)])

	merchantgui.show_merchant(entity, data)

	var cb3: Callable = Callable(self, "_on_merchant_updated")
	if not entity.merchant_updated.is_connected(cb3):
		entity.merchant_updated.connect(cb3)

	# ensure we listen for leave events
	var cb_left: Callable = Callable(self, "_on_merchant_left")
	if (
		entity.has_signal("player_left_merchant")
		and not entity.player_left_merchant.is_connected(cb_left)
	):
		entity.player_left_merchant.connect(cb_left)
	$Inventory/Inner/InventoryLabel/Label.text = "Merchant"


func _on_node_added(node: Node) -> void:
	if node == null:
		return
	if node.is_in_group("merchant_entity"):
		#print("NEW MERCHANT ADDED, CONNECTING:", node)
		var cb: Callable = Callable(self, "_on_merchant_open")
		if not node.player_entered_merchant.is_connected(cb):
			node.player_entered_merchant.connect(cb)

		var cb_left: Callable = Callable(self, "_on_merchant_left")
		if (
			node.has_signal("player_left_merchant")
			and not node.player_left_merchant.is_connected(cb_left)
		):
			node.player_left_merchant.connect(cb_left)


func _on_merchant_updated(updated):
	#print("rebuild Merchant")
	merchantgui._rebuild(updated)


func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		(node as Control).mouse_filter = filter
	for c in node.get_children():
		_set_mouse_filter_recursive(c, filter)


func _on_merchant_left(_entity = null) -> void:
	current_merchant = null
	merchant_in_range = false
	merchantgui.clear()
	_disable_merchant_ui()
	$Inventory/Inner/InventoryLabel/Label.text = "Inventory"
