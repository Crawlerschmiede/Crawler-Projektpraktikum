class_name Skilltree

extends Resource

const SKILLS := preload("res://scripts/entity/premade_skills.gd")
var existing_skills = SKILLS.new()
# format here is name:{tier, skills}
# tier is the level of the tree, 0 being unselected
#skills should be in the format [name, required tier]
var skilltrees = {
	"basic": 0,
	"Short Ranged Weaponry": 0,
	"Medium Ranged Weaponry": 0,
	"Long Ranged Weaponry": 0,
	"Unarmed": 0
}


func get_active_skills():
	var active_skills = []
	var active_trees = []
	for wanted_tree in skilltrees:
		if skilltrees[wanted_tree] == 0:
			continue
		else:
			active_trees.append(wanted_tree)
	for active_tree in active_trees:
		var skills_in_tree = existing_skills.get_skills_by_tree(active_tree)
		print("skills in tree: ", skills_in_tree)
		for skill_in_tree in skills_in_tree:
			if skill_in_tree[1].has("tier"):
				if skill_in_tree[1].tier <= skilltrees[active_tree]:
					active_skills.append(skill_in_tree[0])
	return active_skills


func increase_tree_level(tree_name: String):
	if not skilltrees.has(tree_name):
		push_warning("Unknown skilltree: %s" % tree_name)
		return
	skilltrees[tree_name] = int(skilltrees[tree_name]) + 1


func get_all_explanations():
	var tree_explanations = {}
	for tree in skilltrees:
		tree_explanations[tree] = get_explanation(tree)
	return tree_explanations


func get_explanation(tree_name):
	return existing_skills.get_tree_explanation(tree_name)
