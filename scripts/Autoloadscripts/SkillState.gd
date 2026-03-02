extends Node

const SKILLTREES := preload("res://scripts/entity/premade_skilltrees.gd")
var skilltrees := SKILLTREES.new()

var selected_skills: Array[String] = []

var next_necessary_xp = 2
var current_xp = 0

var skill_scene_paths := {
	"Cleric": "res://scenes/UI/Skills/Cleric.tscn",
	"Long-Ranged-Weaponry": "res://scenes/UI/Skills/Long-Ranged-Weaponry.tscn",
	"Mage": "res://scenes/UI/Skills/Mage.tscn",
	"Medium-Ranged-Weaponry": "res://scenes/UI/Skills/Medium-Ranged-Weaponry.tscn",
	"Rogue": "res://scenes/UI/Skills/Rogue.tscn",
	"Short-Ranged-Weaponry": "res://scenes/UI/Skills/Short-Ranged-Weaponry.tscn",
	"Unarmed-Combat": "res://scenes/UI/Skills/Unarmed-Combat.tscn",
	"Warrior": "res://scenes/UI/Skills/Warrior.tscn"
}


func reset() -> void:
	selected_skills.clear()
	next_necessary_xp = 2
	current_xp = 0

	if skilltrees != null and skilltrees.has_method("reset"):
		skilltrees.reset()
	else:
		skilltrees = SKILLTREES.new()


func export_state() -> Dictionary:
	var tree_levels: Dictionary = {}
	if skilltrees != null and "skilltrees" in skilltrees:
		tree_levels = (skilltrees.skilltrees as Dictionary).duplicate(true)

	return {
		"selected_skills": selected_skills.duplicate(),
		"tree_levels": tree_levels,
		"current_xp": int(current_xp),
		"next_necessary_xp": int(next_necessary_xp),
	}


func import_state(state: Dictionary) -> void:
	if typeof(state) != TYPE_DICTIONARY:
		return

	if skilltrees != null and skilltrees.has_method("import_levels"):
		skilltrees.import_levels(state.get("tree_levels", {}))

	selected_skills.clear()
	var loaded_selected_skills: Variant = state.get("selected_skills", [])
	if typeof(loaded_selected_skills) == TYPE_ARRAY:
		for skill in loaded_selected_skills:
			selected_skills.append(str(skill))

	current_xp = int(state.get("current_xp", 0))
	next_necessary_xp = int(state.get("next_necessary_xp", 2))
