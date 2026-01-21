extends CharacterBody2D

const ACCELERATION = 460.0
const MAX_SPEED = 225.0

var item_name := "Hund"
var player: Node2D = null
var being_picked_up := false


func _physics_process(delta):
	if not being_picked_up:
		pass
	else:
		var direction = global_position.direction_to(player.global_position)
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
		print(global_position.distance_to(player.global_position))
		if global_position.distance_to(player.global_position) < 20:
			PlayerInventory.add_item(item_name, 1)
			queue_free()

	move_and_slide()


func pick_up_item(body):
	print("pickup_started")
	player = body
	being_picked_up = true
