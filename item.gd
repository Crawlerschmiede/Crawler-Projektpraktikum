extends Control

@export var item_name: String = ""
@export var item_quantity: int = 1

@onready var icon: TextureRect = $TextureRect
@onready var qty_label: Label = $Label


func _ready() -> void:
	randomize()

	# Wenn item_name leer ist, nimm irgendeinen vorhandenen Key aus JSON
	if item_name == "":
		if JsonData != null and JsonData.item_data != null and JsonData.item_data.size() > 0:
			var keys := JsonData.item_data.keys()
			item_name = str(keys[randi() % keys.size()])
		else:
			push_error("JsonData.item_data ist leer oder fehlt!")
			return

	_set_icon()

	# StackSize sicher laden
	var item_info: Dictionary = JsonData.item_data.get(item_name, {})
	var stack_size: int = int(item_info.get("StackSize", 1))

	item_quantity = (randi() % stack_size) + 1
	_update_label(stack_size)


func set_item(nm: String, qt: int) -> void:
	item_name = nm
	item_quantity = qt

	_set_icon()

	var item_info: Dictionary = JsonData.item_data.get(item_name, {})
	var stack_size: int = int(item_info.get("StackSize", 1))
	_update_label(stack_size)


func add_item_quantity(amount_to_add: int) -> void:
	item_quantity += amount_to_add
	qty_label.text = str(item_quantity)


func decrease_item_quantity(amount_to_remove: int) -> void:
	item_quantity -= amount_to_remove
	qty_label.text = str(item_quantity)


func _set_icon() -> void:
	var path := "res://item_icons/%s.png" % item_name
	var tex := load(path)

	if tex == null:
		push_warning("Icon nicht gefunden: " + path)
		return

	icon.texture = tex


func _update_label(stack_size: int) -> void:
	if stack_size <= 1:
		qty_label.visible = false
	else:
		qty_label.visible = true
		qty_label.text = str(item_quantity)
