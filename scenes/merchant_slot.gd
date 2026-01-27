extends Panel

@export var slot_index: int = -1
@export var slotType: int = 0

const ItemScene: PackedScene = preload("res://scenes/Item/item.tscn")

var display_item: InventoryItem = null


# ----------------------------------
# READY
# ----------------------------------
func _ready() -> void:
	pass


# ----------------------------------
# ITEM SETZEN (Anzeige only)
# ----------------------------------
func initialize_item(item_name: String, item_quantity: int) -> void:
	clear_slot()

	display_item = ItemScene.instantiate()
	add_child(display_item)

	display_item.position = Vector2.ZERO

	await display_item.ready

	display_item.set_item(item_name, item_quantity)


# ----------------------------------
# SLOT LEEREN
# ----------------------------------
func clear_slot() -> void:
	if display_item and is_instance_valid(display_item):
		display_item.queue_free()
	display_item = null
