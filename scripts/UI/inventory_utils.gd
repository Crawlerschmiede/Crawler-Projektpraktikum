class_name InventoryUtils
extends RefCounted


static func has_property(obj: Object, prop: StringName) -> bool:
	if obj == null:
		return false
	var plist: Array[Dictionary] = obj.get_property_list()
	for p: Dictionary in plist:
		if p.has("name") and StringName(p["name"]) == prop:
			return true
	return false
