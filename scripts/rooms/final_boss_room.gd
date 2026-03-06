extends Area2D

@onready var bossenterd = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if (
		typeof(AudioManager) != TYPE_NIL
		and AudioManager != null
		and AudioManager.has_method("set_in_final_boss_room")
	):
		AudioManager.set_in_final_boss_room(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	return


func _on_body_entered_boss_area(_body: Node2D) -> void:
	if bossenterd == 0:
		print("final boss area entered the first time")
	else:
		print("final boss area entered the second time")


func _on_area_2d_entrance_area_entered(_area: Area2D) -> void:
	return


func _exit_tree() -> void:
	if (
		typeof(AudioManager) != TYPE_NIL
		and AudioManager != null
		and AudioManager.has_method("set_in_final_boss_room")
	):
		AudioManager.set_in_final_boss_room(false)
