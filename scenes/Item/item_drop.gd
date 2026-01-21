extends CharacterBody2D

const ACCELERATION: float = 460.0
const MAX_SPEED: float = 225.0

@export var item_name: String = "Hund"

var player: Node2D = null
var being_picked_up: bool = false
var data: Dictionary = {}   # wird in _ready gesetzt


<<<<<<< HEAD
func _ready() -> void:
	# JsonData sicher prüfen
	if JsonData == null or not ("item_data" in JsonData):
		push_error("JsonData.item_data fehlt! Pickup Item wird entfernt.")
		queue_free()
		return

	data = JsonData.item_data

	# Existiert Item?
	if not _item_exists(item_name):
		push_warning("Pickup entfernt: Item '%s' nicht definiert in JsonData.item_data" % item_name)
		queue_free()
		return

	# Gruppe aus JSON setzen (optional)
	var info: Dictionary = data[item_name] as Dictionary
	var group_name: String = str(info["group"])
	if group_name != "":
		add_to_group(group_name)
		print("add to Group: ", group_name)
=======
func _physics_process(delta):
	if not being_picked_up:
		pass
>>>>>>> 3a3d44c7fb4e9c251d892325a6741b7fbebd6080
	else:
		add_to_group("Inventory")
		print("add to Group: ", "Inventar")


func _physics_process(delta: float) -> void:
	if being_picked_up and player != null and is_instance_valid(player):
		var direction: Vector2 = global_position.direction_to(player.global_position)
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
<<<<<<< HEAD

		if global_position.distance_to(player.global_position) < 20.0:
=======
		print(global_position.distance_to(player.global_position))
		if global_position.distance_to(player.global_position) < 20:
>>>>>>> 3a3d44c7fb4e9c251d892325a6741b7fbebd6080
			PlayerInventory.add_item(item_name, 1)
			queue_free()

	move_and_slide()


<<<<<<< HEAD
func pick_up_item(body: Node2D) -> void:
=======
func pick_up_item(body):
>>>>>>> 3a3d44c7fb4e9c251d892325a6741b7fbebd6080
	print("pickup_started")
	player = body
	being_picked_up = true


func _item_exists(nm: String) -> bool:
	return data.has(nm)
