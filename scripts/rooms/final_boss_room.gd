extends Node2D


func _ready() -> void:
	if (
		typeof(AudioManager) != TYPE_NIL
		and AudioManager != null
		and AudioManager.has_method("set_in_final_boss_room")
	):
		AudioManager.set_in_final_boss_room(true)


func _exit_tree() -> void:
	if (
		typeof(AudioManager) != TYPE_NIL
		and AudioManager != null
		and AudioManager.has_method("set_in_final_boss_room")
	):
		AudioManager.set_in_final_boss_room(false)
