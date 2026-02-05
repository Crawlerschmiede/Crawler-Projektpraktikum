extends HBoxContainer

signal buy_attempt(slot)

@export var item_count: int = 0
@export var item_name: String = ""
@export var price: int = 0
@export var icon_path: String = "res://assets/menu/UI_TravelBook_IconStar01a.png"
@export var buy_amount: int = 1

var sold := false
var can_buy := true
var visible_buy_amount: int = 0

@onready var item = $item
@onready var price_node = $price


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()


func set_price(v: int) -> void:
	price = int(v)
	_refresh()


func _refresh() -> void:
	if price_node == null:
		return
	# Show item in UI
	item.initialize_item(item_name, 1)

	var one_available := int(item_count) >= 1
	var player_has_space := true
	if (
		typeof(PlayerInventory) != TYPE_NIL
		and PlayerInventory != null
		and PlayerInventory.has_method("can_add_amount")
	):
		player_has_space = PlayerInventory.can_add_amount(item_name, 1) >= 1

	if one_available and player_has_space:
		visible_buy_amount = 1
	else:
		visible_buy_amount = 0

	# Show total price for one unit (or 0)
	var total_price = int(price) * max(visible_buy_amount, 0)
	price_node.initialize_item("Coin", total_price)

	# Determine if player has enough coins for the unit price
	if (
		typeof(PlayerInventory) != TYPE_NIL
		and PlayerInventory != null
		and PlayerInventory.has_method("has_coins")
	):
		can_buy = PlayerInventory.has_coins(total_price)
	else:
		can_buy = true

	# mark sold when no stock left for this slot
	sold = (visible_buy_amount <= 0)

	# hide this control when nothing left to buy
	visible = not sold

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
