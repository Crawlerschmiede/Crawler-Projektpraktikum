class_name Skilltree

extends Resource

# format here is name:{tier, skills}
# tier is the level of the tree, 0 being unselected
#skills should be in the format [name, required tier]
var skilltrees = {
	"unarmed":
	{
		"tier": 0,
		"skills":
		[
			["Punch", 1],
			["Right Pivot", 2],
			["Left Pivot", 2],
			["Strong as frick", 1],
			["Full Power Punch", 4]
		]
	}
}


func get_active_skills():
	var active_skills = []
	for wanted_tree in skilltrees:
		print(wanted_tree)
		if skilltrees[wanted_tree]["tier"] == 0:
			continue
		else:
			for skill in skilltrees[wanted_tree]["skills"]:
				if skill[1] <= skilltrees[wanted_tree]["tier"]:
					active_skills.append(skill[0])
	return active_skills


func increase_tree_level(tree_name: String):
	var wanted_tree = skilltrees[tree_name]
	wanted_tree["tier"] = wanted_tree["tier"] + 1
