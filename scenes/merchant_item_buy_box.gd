extends HBoxContainer

signal buy_attempt(item_name: String, price: int)

@onready var item = $item
@onready var price_node = $price

@export var item_name: String = ""
@export var price: int = 1
@export var icon_path: String = "res://assets/menu/UI_TravelBook_IconStar01a.png"

var sold := false
var can_buy := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()


# -------------------------------------------------
# PUBLIC
# -------------------------------------------------
func set_price(v: int) -> void:
	price = int(v)
	_refresh()


# -------------------------------------------------
# UI UPDATE
# -------------------------------------------------
func _refresh() -> void:
	if price_node == null:
		return

	# Preis setzen
	if price_node is Label:
		price_node.text = str(price)
	else:
		var label: Label = price_node.get_node_or_null("Label")
		if label == null:
			label = Label.new()
			label.name = "Label"
			price_node.add_child(label)
		label.text = str(price)

	# Coins prüfen
	if typeof(PlayerInventory) != TYPE_NIL and PlayerInventory != null and PlayerInventory.has_method("has_coins"):
		can_buy = PlayerInventory.has_coins(price)
	else:
		can_buy = true

	_update_visual_state()


# -------------------------------------------------
# GRAU / NORMAL
# -------------------------------------------------
func _update_visual_state() -> void:
	if sold or not can_buy:
		modulate = Color(0.5, 0.5, 0.5, 1.0) # ausgegraut
	else:
		modulate = Color(1, 1, 1, 1)

# -------------------------------------------------
# BUY LOGIC
# -------------------------------------------------
func _try_buy() -> void:
	if item_name == "":
		push_warning("No item_name set")
		return

	if typeof(PlayerInventory) == TYPE_NIL or PlayerInventory == null:
		push_error("PlayerInventory missing")
		return

	# Geld abziehen
	var success := false

	if PlayerInventory.has_method("spend_coins"):
		success = PlayerInventory.spend_coins(price)
	else:
		if "coins" in PlayerInventory and PlayerInventory.coins >= price:
			PlayerInventory.coins -= price
			success = true

	if not success:
		can_buy = false
		_update_visual_state()
		return

	# Item geben
	if PlayerInventory.has_method("add_item"):
		PlayerInventory.add_item(item_name, 1)

	# Mark as sold
	sold = true
	_update_visual_state()

	emit_signal("buy_attempt", item_name, price)
