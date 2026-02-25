extends Control

signal closed

var already_leveled:bool = false
var allowed_levels:int = 1

@onready var container = $SkillContainer
var skill_scenes = []


func _ready():
	for skill_id in SkillState.selected_skills:
		var scene_path = SkillState.skill_scene_paths[skill_id]
		var skill_scene = load(scene_path)

		var skill_instance = skill_scene.instantiate()

		container.add_child(skill_instance)
		if skill_instance is Control:
			skill_scenes.append(skill_instance)
			skill_instance.custom_minimum_size.y = 156
			if skill_instance.has_signal("leveled_up"):
				skill_instance.leveled_up.connect(_on_leveling)

func _on_leveling():
	allowed_levels-=1
	if allowed_levels <= 0:
		already_leveled = true
		closed.emit()
		queue_free()

func _on_continue_pressed() -> void:
	if already_leveled:
		closed.emit()
		queue_free()
