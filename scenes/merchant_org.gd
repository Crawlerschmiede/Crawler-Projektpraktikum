extends VBoxContainer

@export var merchant_slot = preload("res://scenes/merchant_slot.tscn")

var current_merchant


func show_merchant(entity, data: Dictionary):
	current_merchant = entity

	if not current_merchant.merchant_updated.is_connected(_on_merchant_updated):
		current_merchant.merchant_updated.connect(_on_merchant_updated)

	_rebuild(data)

func _on_merchant_updated(data: Dictionary):
	_rebuild(data)
	pass



func _rebuild(data: Dictionary):
	clear()
	await get_tree().process_frame
	
	for i in range(data["items"].size()):
		var slot = merchant_slot.instantiate()
		add_child(slot)

		var item = data["items"][i]

		slot.item_name = item["name"]
		slot.item_count = item["count"]
		print(item["count"])
		slot.price = item["price"]

		slot._refresh()

		var idx := i

		# 🔥 Signal vom Slot abfangen
		slot.buy_attempt.connect(func(_slot):
			if current_merchant != null:
				current_merchant.buy_item(idx)
			else:
				push_warning("current_merchant is null")
		)

func clear():
	for c in get_children():
		c.queue_free()
