extends Control

signal closed
var Inventory = load("res://scenes/entity/player-character-scene.tscn")


func _ready():
	# Loop through all children to find Buttons and Sprites
	for btn in find_children("*", "Button", true):
		btn.pressed.connect(_on_element_clicked.bind(btn.name))
	for sprite in find_children("*", "AnimatedSprite2D", true):
		# Check if the sprite has our custom signal before connecting
		if sprite.has_signal("clicked"):
			sprite.clicked.connect(_on_element_clicked)


#func _input(event):
#	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
#		get_tree().change_scene_to_file("res://scenes/entity/player-character-scene.tscn")


func _on_element_clicked(element_name: String):
	print("Clicked: ", element_name)

	match element_name:
		"InventoryLabel", "InventoryIcon":
			#idea1
			#Input.action_press("open_inventory")
			#Input.action_release("open_inventory")
			#idea2
			#get_tree().call_group("Inventory", "force_toggle_inventory")
			#closed.emit()
			return

		"SettingsLabel", "SettingsIcon":
			get_tree().change_scene_to_file("res://scenes/UI/settings_menu.tscn")
		"MenuLabel", "MenuIcon":
			get_tree().change_scene_to_file("res://scenes/UI/popup-menu.tscn")
