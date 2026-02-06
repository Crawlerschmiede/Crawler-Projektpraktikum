extends CharacterBody2D

const ACCELERATION: float = 460.0
const MAX_SPEED: float = 225.0

@export var item_name: String = "Hund"

var player: Node2D = null
var being_picked_up: bool = false
var data: Dictionary = {}  # wird in _ready gesetzt


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
	else:
		add_to_group("Inventory")


func _physics_process(delta: float) -> void:
	if being_picked_up and player != null and is_instance_valid(player):
		var direction: Vector2 = global_position.direction_to(player.global_position)
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)

		if global_position.distance_to(player.global_position) < 20.0:
			PlayerInventory.add_item(item_name, 1)
			queue_free()

	move_and_slide()


func pick_up_item(body: Node2D) -> void:
	player = body
	being_picked_up = true


func _item_exists(nm: String) -> bool:
	return data.has(nm)
