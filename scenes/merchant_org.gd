extends VBoxContainer

@export var merchant_slot = preload("res://scenes/merchant_slot.tscn")

var current_merchant: MerchantEntity


func show_merchant(entity: MerchantEntity, data: Dictionary):
	current_merchant = entity
	_rebuild(data)


func _rebuild(data: Dictionary):
	clear()

	for i in range(data["items"].size()):
		var slot = merchant_slot.instantiate()
		add_child(slot)

		var item = data["items"][i]

		slot.item_name = item["name"]
		slot.item_count = item["count"]
		slot.price = item["price"]

		slot._refresh()

		# click -> buy
		slot.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				current_merchant.buy_item(i))


func clear():
	for c in get_children():
		c.queue_free()
