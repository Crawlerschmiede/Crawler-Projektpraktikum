extends VBoxContainer

@export var merchant_slot = preload("res://scenes/merchant_slot.tscn")

var current_merchant


func show_merchant(entity, data: Dictionary):
	current_merchant = entity

	# Connect to the merchant's update signal so UI refreshes after purchases
	var cb := Callable(self, "_on_merchant_updated")
	if not current_merchant.is_connected("merchant_updated", cb):
		current_merchant.connect("merchant_updated", cb)

	_rebuild(data)

func _on_merchant_updated(data: Dictionary):
	call_deferred("_rebuild", data)



func _rebuild(data: Dictionary):
	clear()

	for i in range(data["items"].size()):
		var slot = merchant_slot.instantiate()

		var item = data["items"][i]
		slot.item_name = item["name"]
		slot.item_count = item["count"]
		slot.price = item["price"]

		# package size: allow per-item override from merchant data
		slot.buy_amount = int(item.get("buy_amount", current_merchant.sell_batch))

		add_child(slot)
		slot._refresh()

		var idx := i
		slot.buy_attempt.connect(func(_slot):
			if current_merchant:
				var success = current_merchant.buy_item(idx, int(_slot.item_count))
				if not success:
					push_warning("Kauf fehlgeschlagen (z.B. zu wenig Coins oder nicht genug Bestand)")
		)


func clear():
	for c in get_children():
		c.queue_free()
