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
func _process(delta: float) -> void:
	pass


func _on_body_entered_boss_area(body: Node2D) -> void:
	if bossenterd == 0:
		print("final boss area entered the first time")
	else:
		print("final boss area entered the second time")
	pass  # Replace with function body.


func _on_area_2d_entrance_area_entered(area: Area2D) -> void:
	pass  # Replace with function body.


func _exit_tree() -> void:
	if (
		typeof(AudioManager) != TYPE_NIL
		and AudioManager != null
		and AudioManager.has_method("set_in_final_boss_room")
	):
		AudioManager.set_in_final_boss_room(false)
