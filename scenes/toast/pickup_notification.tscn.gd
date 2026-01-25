extends Panel

@onready var label: Label = $HBoxContainer/Label
@onready var holder: CenterContainer = $HBoxContainer/CenterContainer


const ItemScene: PackedScene = preload("res://scenes/Item/item.tscn")

var tween: Tween
var item_ui: Node = null

func setup(item_name: String, amount: int) -> void:
	label.text = "%s x%d" % [item_name, amount]
	modulate.a = 0.0

	# altes item entfernen
	if item_ui != null and is_instance_valid(item_ui):
		item_ui.queue_free()
	item_ui = null

	# neues item icon erstellen
	item_ui = ItemScene.instantiate()
	holder.add_child(item_ui)

	item_ui = ItemScene.instantiate()
	holder.add_child(item_ui)

	if item_ui is Control:
		var c := item_ui as Control
		c.scale = Vector2(6, 6)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


	# Item setzen wie im Slot!
	if item_ui.has_method("set_item"):
		item_ui.call("set_item", item_name, amount)


func play() -> void:
	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
