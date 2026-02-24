extends Control

signal closed

@onready var container = $SkillContainer


func _ready():
	for skill_id in SkillState.selected_skills:
		var scene_path = SkillState.skill_scene_paths[skill_id]
		var skill_scene = load(scene_path)

		var skill_instance = skill_scene.instantiate()

		container.add_child(skill_instance)
		if skill_instance is Control:
			skill_instance.custom_minimum_size.y = 156


func _on_continue_pressed() -> void:
	closed.emit()
	queue_free()
