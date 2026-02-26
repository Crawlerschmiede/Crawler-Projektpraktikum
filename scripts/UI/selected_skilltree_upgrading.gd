extends Control

signal closed

var already_leveled: bool = false
var allowed_levels: int = 1

@onready var container = $SkillContainer
var skill_scenes = []


func _ready():
	# Defensive: SkillState Autoload may be missing in some contexts
	if typeof(SkillState) == TYPE_NIL:
		push_error("selected_skilltree_upgrading: SkillState autoload is not available")
		return

	var sel = SkillState.selected_skills
	if sel == null or typeof(sel) != TYPE_ARRAY:
		push_warning("selected_skilltree_upgrading: no selected skills to show")
		return

	for skill_id in sel:
		if SkillState.skill_scene_paths == null or not SkillState.skill_scene_paths.has(skill_id):
			push_warning(
				"selected_skilltree_upgrading: missing scene path for skill: %s" % skill_id
			)
			continue
		var scene_path = SkillState.skill_scene_paths[skill_id]
		var skill_scene = load(scene_path)
		if skill_scene == null:
			push_warning("selected_skilltree_upgrading: failed to load scene for %s" % skill_id)
			continue

		var skill_instance = skill_scene.instantiate()

		container.add_child(skill_instance)
		if skill_instance is Control:
			skill_scenes.append(skill_instance)
			skill_instance.custom_minimum_size.y = 156
			if skill_instance.has_signal("leveled_up"):
				skill_instance.leveled_up.connect(_on_leveling)


func _on_leveling():
	allowed_levels -= 1
	if allowed_levels <= 0:
		already_leveled = true
		closed.emit()
		queue_free()


func _on_continue_pressed() -> void:
	if already_leveled:
		closed.emit()
		queue_free()
