class_name Skilltree

extends Resource


const SKILLS := preload("res://scripts/entity/premade_skills.gd")
var existing_skills = SKILLS.new()
# format here is name:{tier, skills}
# tier is the level of the tree, 0 being unselected
#skills should be in the format [name, required tier]
var skilltrees = {
	"unarmed": 0,
	"Short Ranged Weaponry":0,
	"Medium Ranged Weaponry":0,
	"Long Ranged Weaponry":0,
}


func get_active_skills():
	var active_skills = []
	var active_trees =[]
	for wanted_tree in skilltrees:
		if skilltrees[wanted_tree] == 0:
			continue
		else:
			active_trees.append(wanted_tree)
	for active_tree in active_trees:
		var skills_in_tree = existing_skills.get_skills_by_tree(active_tree)
		print(skills_in_tree)
		for skill_in_tree in skills_in_tree:
			if skill_in_tree.has("tier"):
				if skill_in_tree.tier<=skilltrees[active_tree]:
					active_skills.append(skill_in_tree.skill_in_tree)
	return active_skills


func increase_tree_level(tree_name: String):
	skilltrees[tree_name] = skilltrees[tree_name] + 1
