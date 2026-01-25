extends CanvasLayer

var holding_item = null

@onready var hot_container := $Inventory/Hotbar/HotContainer
@onready var equipment := $Inventory/Inner/Equiptment
@onready var equipmentlabel := $Inventory/Inner/EquiptmentLabel
@onready var player:= $".."
@onready var merchantgui:= $Inventory/Inner/MerchantContainer

@onready var coin_screen = $Inventory/price

func _input(event):
	if event.is_action_pressed("open_inventory"):
		$Inventory/Inner.visible = !$Inventory/Inner.visible
	
	if player.tilemap.get_cell_tile_data(player.grid_pos).get_custom_data("merchant"):
		equipment.visible = false
		equipmentlabel.visible = false
		merchantgui.visible = true
	else:
		equipment.visible = true
		equipmentlabel.visible = true
		merchantgui.visible = false
		
	# Hotbar 1..5 -> SlotIndex 13..17
	for i in range(1, 6):
		if event.is_action_pressed("hotbar_slot%d" % i):
			var slot_index := i + 17
			PlayerInventory.set_selectet_slot(slot_index)
			print("Slot:", slot_index, "selected!")

			_refresh_hotbar_styles()
			return


func _refresh_hotbar_styles() -> void:
	# refresht ALLE Slot-Nodes im HotContainer
	for child in hot_container.get_children():
		if child is Slot:
			child.refresh_style()


func _ready() -> void:
	# Connect coin display to PlayerInventory changes
	if typeof(PlayerInventory) != TYPE_NIL and PlayerInventory != null and PlayerInventory.has_signal("inventory_changed"):
		var cb: Callable = Callable(self, "_update_coin_screen")
		if not PlayerInventory.inventory_changed.is_connected(cb):
			PlayerInventory.inventory_changed.connect(cb)

	# Initial update
	_update_coin_screen()


func _update_coin_screen() -> void:
	$Inventory/coin_sum.initialize_item("coin", PlayerInventory.coins)
