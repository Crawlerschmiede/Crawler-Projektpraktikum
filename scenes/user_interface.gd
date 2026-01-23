extends CanvasLayer

var holding_item = null

@onready var hot_container := $Inventory/Hotbar/HotContainer

func _input(event):
	if event.is_action_pressed("open_inventory"):
		$Inventory/Inner.visible = !$Inventory/Inner.visible

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
