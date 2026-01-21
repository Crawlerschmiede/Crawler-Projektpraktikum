class_name EnemyVampireBat

extends MoveableEntity

const ROAM_COOLDOWN: float = 2
const CHASE_COOLDOWN: float = 0.5

var roam_timer: float = 5.0
var chase_timer: float = 5.0
var burrowed = false
var chased_pos: Vector2i
var chased_direction: Vector2i

var chosen: Skill
var sprite_type: String = "bat"
var behaviour = "idle"
var chase_target: PlayerCharacter
var chasing: bool = false

@onready var sight_area: Area2D = $SightArea


func roam():
	if "burrowing" in types:
		if burrowed:
			burrowed = false
			sprite.play("default")
	chasing = false
	var direction_int = 0
	var direction = Vector2i.ZERO
	direction_int = rng.randi_range(0, 3)

	if direction_int == 0:
		direction = Vector2i.RIGHT
	elif direction_int == 1:
		direction = Vector2i.LEFT
	elif direction_int == 2:
		direction = Vector2i.UP
	elif direction_int == 3:
		direction = Vector2i.DOWN
	if "wallbound" in types:
		if is_next_to_wall(grid_pos + direction):
			move_to_tile(direction)
	else:
		move_to_tile(direction)


func chase():
	if !burrowed:
		chased_pos = chase_target.grid_pos
		chased_direction = chase_target.latest_direction
	var x_move = Vector2i.ZERO
	var y_move = Vector2i.ZERO
	var used_animation = animations
	if !chasing:
		if "burrowing" in types:
			if !burrowed:
				if animations != null and animations.has("teleport_start"):
					sprite.play(animations["teleport_start"])
				else:
					# fallback
					sprite.play("default")
				burrowed = true
				return
			else:
				var animation_array = null
				var digrection = (chased_direction) * -2
				var targ_dig_pos = chased_pos + digrection
				if used_animation:
					if used_animation["teleport_start"] and used_animation["teleport_end"]:
						animation_array = [used_animation["teleport_end"]]
				await teleport_to_tile(targ_dig_pos, animation_array)
				chasing = true
				burrowed = false
				return

	chasing = true
	if chased_pos.x < grid_pos.x:
		x_move = Vector2i.LEFT
	if chased_pos.x > grid_pos.x:
		x_move = Vector2i.RIGHT
	if chased_pos.y < grid_pos.y:
		y_move = Vector2i.UP
	if chased_pos.y > grid_pos.y:
		y_move = Vector2i.DOWN
	if "wallbound" in types:
		if is_next_to_wall(grid_pos + x_move) and x_move != Vector2i.ZERO:
			move_to_tile(x_move)
			chase_timer = CHASE_COOLDOWN
			return
		if is_next_to_wall(grid_pos + y_move) and y_move != Vector2i.ZERO:
			move_to_tile(y_move)
			chase_timer = CHASE_COOLDOWN
			return
	elif "burrowing" in types:
		if tilemap.get_cell_tile_data(grid_pos + x_move) and x_move != Vector2i.ZERO:
			move_to_tile(x_move)
			chase_timer = CHASE_COOLDOWN
			return
		if tilemap.get_cell_tile_data(grid_pos + y_move) and y_move != Vector2i.ZERO:
			move_to_tile(y_move)
			chase_timer = CHASE_COOLDOWN
			return
	else:
		if (
			tilemap.get_cell_tile_data(grid_pos + x_move)
			and !tilemap.get_cell_tile_data(grid_pos + x_move).get_custom_data("non_walkable")
			and x_move != Vector2i.ZERO
		):
			move_to_tile(x_move)
			chase_timer = CHASE_COOLDOWN
			return
		if (
			tilemap.get_cell_tile_data(grid_pos + y_move)
			and !tilemap.get_cell_tile_data(grid_pos + y_move).get_custom_data("non_walkable")
			and y_move != Vector2i.ZERO
		):
			move_to_tile(y_move)
			chase_timer = CHASE_COOLDOWN
			return


func _ready() -> void:
	super_ready(sprite_type, types)
	var player = get_tree().get_first_node_in_group("player")
	player.player_moved.connect(move_it)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	chase_timer -= delta
	roam_timer -= delta


func move_it():
	if multi_turn_action == null:
		var saw_player = check_sight()
		if saw_player:
			if "hostile" in types:
				behaviour = "chase"
		else:
			behaviour = "idle"
			chase_target = null

		if behaviour == "idle":
			roam()
		elif behaviour == "chase":
			chase()
	else:
		if multi_turn_action["countdown"] > 0:
			multi_turn_action["countdown"] = multi_turn_action["countdown"] - 1
		else:
			match multi_turn_action["name"]:
				"dig_to":
					teleport_to_tile(multi_turn_action["target"])
					if has_animation(sprite, "dig_up"):
						sprite.play("dig_up")
						await sprite.animation_finished
						sprite.play("default")
			multi_turn_action = null


func check_sight():
	var saw_player = false
	for body in sight_area.get_overlapping_bodies():
		if body == self:
			continue
		else:
			if body.is_player:
				saw_player = true
				chase_target = body
	return saw_player


func decide_attack() -> void:
	var chosen_index = rng.randi_range(0, len(abilities) - 1)
	chosen = abilities[chosen_index]
	print("Next ability is ", chosen.name)
