class_name EnemyVampireBat

extends MoveableEntity

var roam_timer :float = 5.0
const roam_cooldown: int = 2
func roam(delta):
	roam_timer-=delta
	var direction_int = 0
	var direction =Vector2i.ZERO
	if roam_timer<=0:
		direction_int = rng.randi_range(0, 3)
		
		if direction_int == 0:
			direction = Vector2i.RIGHT
		elif direction_int == 1:
			direction = Vector2i.LEFT
		elif direction_int == 2:
			direction = Vector2i.UP
		elif direction_int == 3:
			direction = Vector2i.DOWN
		move_to_tile(direction)
		roam_timer=roam_cooldown

func _ready() -> void:
	super_ready("enemy_flying")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	sprite.play("default")
	roam(delta)
