class_name MadeSkills

extends Resource

#write skills here as
# name : [skilltree, description, effects]
# The effects should be in the format:
# [[type, value, targets_self, details], [same thing for more effects]]
var existing_skills = {
	"Screech":
	[
		#bat stuff
		"bat things",
		"AAAAAAAAAAAAAAAAAAAAAAAAAAAA",
		[["damage", 1, false, "No"], ["danger_dmg_mult", 2, false, "y=0"]]
	],
	"Swoop":
	[
		"bat things",
		"You'd think a bat headbutting you wouldn't hurt that much... you'd be wrong",
		[["damage", 1, false, "No"], ["danger_dmg_mult", 2, false, "player_x"]]
	],
	"Punch":
	[
		#unarmed player stuff
		"hitting and punching and biting and kicking people",
		"It's a punch... you don't need an explanation",
		[["damage", 2, false, "No"]]
	],
	"Right Pivot":
	[
		"hitting and punching and biting and kicking people",
		"It's a punch BUT you also take a step to the right, how novel!",
		[["damage", 1, false, "No"], ["movement", 1, true, "R"]]
	],
	"Left Pivot":
	[
		"hitting and punching and biting and kicking people",
		"It's a punch BUT you also take a step to the left, how exciting!",
		[["damage", 1, false, "No"], ["movement", 1, true, "L"]]
	],
}


func get_skill(skill_name):
	var values = existing_skills.get(skill_name)
	if values == null:
		return values
	var new_skill = Skill.new(skill_name, values[0], values[1])
	for effect in values[2]:
		new_skill.add_effect(effect[0], effect[1], effect[2], effect[3])
	return new_skill
