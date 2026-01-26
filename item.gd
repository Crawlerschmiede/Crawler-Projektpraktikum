class_name InventoryItem
extends Control

@export var item_name: String = ""
@export var item_quantity: int = 1

# Optional: nur für Tests im Editor
@export var randomize_if_empty_in_editor: bool = false

@onready var icon: TextureRect = $TextureRect
@onready var qty_label: Label = $Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)

	# Kinder dürfen auch keine Klicks fressen:
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_refresh()


# ---------------------------------------------------
# Public API (wird von Slot / InventoryUI benutzt)
# ---------------------------------------------------
func set_item(nm: String, qt: int) -> void:
	item_name = nm
	item_quantity = max(qt, 1)
	_refresh()


func add_item_quantity(amount_to_add: int) -> void:
	item_quantity += max(amount_to_add, 0)
	_refresh()


func decrease_item_quantity(amount_to_remove: int) -> void:
	item_quantity -= max(amount_to_remove, 0)
	if item_quantity < 1:
		item_quantity = 1
	_refresh()


# ---------------------------------------------------
# Internals
# ---------------------------------------------------
func _refresh() -> void:
	_set_icon()

	var stack_size: int = _get_stack_size(item_name)
	_update_label(stack_size)


func item_exists() -> bool:
	if JsonData == null:
		return false
	if not ("item_data" in JsonData):
		return false

	var data: Dictionary = JsonData.item_data
	if not data.has(item_name):
		return false
	return true


func _get_stack_size(name: String) -> int:
	if !item_exists():
		return 1
	var data: Dictionary = JsonData.item_data
	var info: Variant = data[name]
	if typeof(info) != TYPE_DICTIONARY:
		return 1

	var stack_size: int = int((info as Dictionary).get("StackSize", 1))
	return max(stack_size, 1)


func get_bound_skills() -> Array:
	print("Itemname: ", item_name)
	if !item_exists():
		print("doesn't exist")
		return []
	var data: Dictionary = JsonData.item_data
	var info: Variant = data[item_name]
	if typeof(info) != TYPE_DICTIONARY:
		print("not_dict")
		return []
	var bound_skills: Array = Array((info as Dictionary).get("bound_skills", []))
	print("returnin proper")
	return bound_skills


func _set_icon() -> void:
	if item_name == "":
		return

	var path: String = "res://assets/item_icons/%s.png" % item_name
	var tex: Resource = load(path)

	if tex == null:
		push_warning("Icon nicht gefunden: " + path)
		return

	if tex is Texture2D:
		icon.texture = tex as Texture2D


func _update_label(stack_size: int) -> void:
	if stack_size <= 1:
		qty_label.visible = false
	else:
		qty_label.visible = true
		qty_label.text = str(item_quantity)


# ---------------------------
# Debug / Editor Test only
# ---------------------------
func _debug_randomize_if_empty() -> void:
	randomize()

	if item_name == "":
		if JsonData != null and ("item_data" in JsonData) and JsonData.item_data.size() > 0:
			var keys: Array = JsonData.item_data.keys()
			item_name = str(keys[randi() % keys.size()])
			var stack_size: int = _get_stack_size(item_name)
			item_quantity = (randi() % stack_size) + 1
		else:
			push_error("JsonData.item_data ist leer oder fehlt!")
