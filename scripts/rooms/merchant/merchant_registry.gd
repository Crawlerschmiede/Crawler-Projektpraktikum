extends Node

# Simple in-memory registry for merchants during a runtime session
# Stored as: registry[merchant_id] = [{name, count, price}, ...]

var _registry: Dictionary = {}


func get_registry() -> Dictionary:
	# return a shallow copy to avoid external accidental mutation
	var copy = _registry.duplicate(false)
	print("[MerchantRegistry] get_registry ->", copy)
	return copy


func get_items(id: String):
	if id in _registry:
		var v = _registry[id]
		if typeof(v) in [TYPE_ARRAY, TYPE_DICTIONARY]:
			var out = v.duplicate(true)
			print("[MerchantRegistry] get_items(%s) -> %s" % [id, out])
			return out
		return v
	print("[MerchantRegistry] get_items(%s) -> null" % id)
	return null


func set_items(id: String, items) -> void:
	# store a deep copy to avoid holding external references
	if typeof(items) in [TYPE_ARRAY, TYPE_DICTIONARY]:
		_registry[id] = items.duplicate(true)
	else:
		_registry[id] = items
		print("[MerchantRegistry] set_items(%s) -> %s" % [id, _registry[id]])


func has(id: String) -> bool:
	var h = id in _registry
	print("[MerchantRegistry] has(%s) -> %s" % [id, h])
	return h


func clear() -> void:
	_registry.clear()


func reset() -> void:
	# Clear in-memory registry
	_registry.clear()
