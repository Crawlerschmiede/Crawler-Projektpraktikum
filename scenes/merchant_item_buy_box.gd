extends HBoxContainer

signal buy_attempt(slot)

@onready var item = $item
@onready var price_node = $price

@export var item_count: int = 0
@export var item_name: String = ""
@export var price: int = 0
@export var icon_path: String = "res://assets/menu/UI_TravelBook_IconStar01a.png"
@export var buy_amount: int = 1

var sold := false
var can_buy := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()


func set_price(v: int) -> void:
	price = int(v)
	_refresh()


func _refresh() -> void:
	if price_node == null:
		return

	item.initialize_item(item_name, item_count)

	price_node.initialize_item("Coin", price)

	if (
		typeof(PlayerInventory) != TYPE_NIL
		and PlayerInventory != null
		and PlayerInventory.has_method("has_coins")
	):
		can_buy = PlayerInventory.has_coins(price)
	else:
		can_buy = true

	# mark sold when quantity is zero
	sold = int(buy_amount) <= 0
	_update_visual_state()


# -------------------------------------------------
# GRAU / NORMAL
# -------------------------------------------------
func _update_visual_state() -> void:
	if sold or not can_buy:
		modulate = Color(0.5, 0.5, 0.5, 1.0)  # ausgegraut
	else:
		modulate = Color(1, 1, 1, 1)


# -------------------------------------------------
# BUY LOGIC
# -------------------------------------------------
func _try_buy() -> void:
	if sold:
		return
	if not can_buy:
		return
	emit_signal("buy_attempt", self)
