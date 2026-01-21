class_name EnemyVampireBat

extends MoveableEntity

const ROAM_COOLDOWN: float = 2
const CHASE_COOLDOWN: float = 0.5

var roam_timer: float = 5.0
var chase_timer: float = 5.0

var chosen: Skill
var types = ["passive"]
var sprite_type: String = "bat"
var behaviour = "idle"
var chase_target: PlayerCharacter
var chasing: bool = false

@onready var sight_area: Area2D = $SightArea


func roam():
	chasing = false
	var direction_int = 0
	var direction = Vector2i.ZERO
	if roam_timer <= 0:
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
				roam_timer = ROAM_COOLDOWN
		else:
			move_to_tile(direction)
			roam_timer = ROAM_COOLDOWN


func chase():
	var chased_pos = chase_target.grid_pos
	var x_move = Vector2i.ZERO
	var y_move = Vector2i.ZERO
	if !chasing:
		chasing = true
		if "burrowing" in types:
			var digrection = (chase_target.latest_direction)*-2
			var targ_dig_pos = chased_pos + digrection
			
			teleport_to_tile(targ_dig_pos)
			
	if chase_timer <= 0:
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
	setup(tilemap, 3, 1, 0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	chase_timer -= delta
	roam_timer -= delta
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
