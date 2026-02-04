extends VBoxContainer

@export var merchant_slot = preload("res://scenes/merchant_slot.tscn")

var current_merchant


func show_merchant(entity, data: Dictionary):
	current_merchant = entity

	# Connect to the merchant's update signal so UI refreshes after purchases
	var cb := Callable(self, "_on_merchant_updated")
	if not current_merchant.is_connected("merchant_updated", cb):
		current_merchant.connect("merchant_updated", cb)

	# Diagnostic check: ensure data contains items
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("merchant_org.show_merchant: data is not a Dictionary: %s" % [str(data)])
	else:
		if not data.has("items"):
			push_warning("merchant_org.show_merchant: data missing 'items' key: %s" % [str(data)])
		else:
			push_warning(
				"merchant_org.show_merchant: received %d items" % [int(data["items"].size())]
			)

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

		var idx = i
		slot.buy_attempt.connect(
			func(_slot):
				if current_merchant:
					# Use the exact amount displayed in the slot UI when requesting a purchase
					var to_request := 0
					if _slot != null and _slot.has_method("get") and _slot.get("visible_buy_amount") != null:
						to_request = int(_slot.get("visible_buy_amount"))
					else:
						# fallback: compute minimal clamped amount (but clamp to 1 minimum)
						var desired := int(_slot.buy_amount)
						var available := int(_slot.item_count)
						to_request = max(1, min(desired, available))

					var success = current_merchant.buy_item(idx, to_request)
					if not success:
						push_warning("Kauf fehlgeschlagen (z.B. zu wenig Coins oder nicht genug Bestand)"))

	# Wenn vorhanden -> Merchant-spezifische Verkaufspreise an SellSlot(s) weitergeben
	var sell_prices := {}
	for item in data.get("items", []):
		if typeof(item) == TYPE_DICTIONARY and item.has("name"):
			sell_prices[str(item["name"])] = int(item.get("sell_price", 0))

	var sells := get_tree().get_nodes_in_group("SellSlot")
	for s in sells:
		if s == null:
			continue
		# prefer method if provided
		if s.has_method("set_merchant_sell_prices"):
			s.call("set_merchant_sell_prices", sell_prices)
		else:
			# otherwise set a property so SellSlot can read it
			if s.has_method("set"):
				s.set("merchant_sell_prices", sell_prices)

func clear():
	for c in get_children():
		c.queue_free()
