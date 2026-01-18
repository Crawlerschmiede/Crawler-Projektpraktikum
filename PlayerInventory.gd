extends Node

const NUM_INVENTORY_SLOTS := 20
const SlotClass = preload("res://scenes/Slot.gd")
const ItemClass = preload("res://item.gd")
# slot_index -> [item_name, item_quantity]
var inventory := {}

signal inventory_changed


func _ready() -> void:
	# optional: test item
	# inventory[0] = ["Iron Sword", 1]
	pass


func add_item(item_name: String, item_quantity: int = 1) -> void:
	# 1) Wenn Item schon existiert: stacke es
	print("before: ", inventory)
	for slot in inventory.keys():
		if inventory[slot][0] == item_name:
			inventory[slot][1] += item_quantity
			inventory_changed.emit()
			print("after: ", inventory)
			return
	# 2) Item existiert nicht -> erstes freies Slot suchen
	for i in range(NUM_INVENTORY_SLOTS):
		if not inventory.has(i):
			inventory[i] = [item_name, item_quantity]
			inventory_changed.emit()
			print("after: ", inventory)
			return

	print("Inventar voll! Item nicht hinzugefuegt: ", item_name)


func remove_item(slot: Node) -> void:
	inventory.erase(slot.slot_index)


func clear_inventory() -> void:
	inventory.clear()
	inventory_changed.emit()
