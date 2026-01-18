extends CanvasLayer
var holding_item = null

func _input(event):
	if event.is_action_pressed("open_inventory"):
		$Inventory.visible = !$Inventory.visible
		#$Inventory.initialize_inventory()

func _ready():
	pass # Replace with function body.
