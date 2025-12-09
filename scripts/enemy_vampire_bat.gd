class_name EnemyVampireBat

extends MoveableEntity


func _ready() -> void:
	super_ready("enemy_flying")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	sprite.play("default")
