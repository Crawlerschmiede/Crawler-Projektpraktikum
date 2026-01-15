class_name EnemyVampireBat

extends MoveableEntity

const ROAM_COOLDOWN: int = 2

var roam_timer: float = 5.0

var chosen: Skill
var types = ["passive"]
var sprite_type: String = "bat"


func roam(delta):
	roam_timer -= delta
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


func _ready() -> void:
	abilities_this_has = ["Screech", "Swoop", "Rabies"]
	super_ready(sprite_type, types)
	setup(tilemap, 3, 1, 0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	roam(delta)


func decide_attack() -> void:
	var chosen_index = rng.randi_range(0, len(abilities) - 1)
	chosen = abilities[chosen_index]
	print("Next ability is ", chosen.name)
