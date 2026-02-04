class_name Slot
extends Panel

enum SlotType {
	HOTBAR = 0,
	INVENTORY = 1,
}

const SLOT_TEXTURE: Texture2D = preload("res://assets/menu/UI_TravelBook_Slot01b.png")
const ITEM_SCENE: PackedScene = preload("res://scenes/Item/item.tscn")

@export var slot_index: int = -1
@export var slot_type: int = 0  # SlotType enum value

# Textures
@export var default_tex: Texture2D = SLOT_TEXTURE
@export var empty_tex: Texture2D = SLOT_TEXTURE
@export var selected_tex: Texture2D = preload("res://assets/menu/Selected_slot.png")
@export var hover_tex: Texture2D = preload("res://assets/menu/Mülltonne_open.png")
@export var has_background: bool = true

var default_style: StyleBoxTexture
var empty_style: StyleBoxTexture
var selected_style: StyleBoxTexture
var trash_style: StyleBoxTexture

# Item
var item: Node = null

var _ui: Node = null


func _ready() -> void:
	_ui = find_parent("UserInterface")
	if has_background:
		default_style = StyleBoxTexture.new()
		empty_style = StyleBoxTexture.new()
		selected_style = StyleBoxTexture.new()
		trash_style = StyleBoxTexture.new()

		default_style.texture = default_tex
		empty_style.texture = empty_tex
		selected_style.texture = selected_tex
		trash_style.texture = hover_tex

	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)

	refresh_style()


func _fit_item_to_slot(it: Node) -> void:
	if it == null:
		return
	if not (it is Control):
		return

	var c := it as Control

	c.set_anchors_preset(Control.PRESET_FULL_RECT)

	# offsets clean setzen
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0

	# Sicherheit: gleiche Größe
	c.size = size
	c.position = Vector2.ZERO

	for g in get_groups():
		var regex := RegEx.new()
		regex.compile("^scale_([0-9]+(?:\\.[0-9]+)?)$")

		var result := regex.search(g)
		if result:
			print("Scale Result: ", result)
			var scale_value := float(result.get_string(1))
			c.scale = Vector2(scale_value, scale_value)


func _on_mouse_entered() -> void:
	if self.name == "Slot12":
		set("theme_override_styles/panel", trash_style)


func _on_mouse_exited() -> void:
	# Return to normal when mouse leaves
	refresh_style()


func refresh_style() -> void:
	#print(PlayerInventory.get_selected_slot())
	#print(item)
	if item != null and (not is_instance_valid(item) or item.get_parent() != self):
		item = null

	if has_background:
		if PlayerInventory.get_selected_slot() == slot_index:
			set("theme_override_styles/panel", selected_style)
		elif item == null:
			set("theme_override_styles/panel", empty_style)
		else:
			set("theme_override_styles/panel", default_style)


func pick_from_slot() -> void:
	if item == null:
		return

	var moving := item
	item = null  # <<< SOFORT

	var ui := find_parent("UserInterface")
	if ui == null:
		return

	if moving.get_parent() == self:
		remove_child(moving)

	ui.add_child(moving)

	if moving is CanvasItem:
		var ci := moving as CanvasItem
		ci.top_level = true
		ci.z_index = 999

	moving.global_position = get_global_mouse_position()

	refresh_style()


func put_into_slot(new_item: Node) -> void:
	if new_item == null:
		return

	var ui := find_parent("UserInterface")
	if ui != null and is_instance_valid(ui) and new_item.get_parent() == ui:
		ui.remove_child(new_item)

	# In Slot hängen
	add_child(new_item)

	if new_item is CanvasItem:
		var ci := new_item as CanvasItem
		ci.top_level = false
		ci.z_index = 0
		ci.visible = true

	_fit_item_to_slot(new_item)

	new_item.position = Vector2.ZERO
	item = new_item
	refresh_style()


func clear_slot() -> void:
	if item != null and is_instance_valid(item):
		item.queue_free()
	item = null
	refresh_style()


func initialize_item(item_name: String, item_quantity: int) -> void:
	if item == null:
		item = ITEM_SCENE.instantiate()
		add_child(item)
		_fit_item_to_slot(item)

	# Erwartet dass dein Item Node eine set_item(name, qty) Methode besitzt
	if item.has_method("set_item"):
		item.call("set_item", item_name, item_quantity)
	else:
		push_error("Item Scene hat keine Methode set_item(item_name, item_quantity)")

	refresh_style()


func get_item():
	return item
