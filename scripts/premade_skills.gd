class_name MadeSkills

extends Resource

#write skills here as
# name : [skilltree, description, effects]
# The effects should be in the format:
# [[type, value, targets_self, details], [same thing for more effects]...]]
#for dmg reduction, 1 means full damage taken and 0 means full immunity with float values in between
var existing_skills = {
	#bat stuff
	"Screech":
	[
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
	"Rabies":
	["bat things", "It's a wild animal. They have this sometimes", [["poison", 2, false, "No"]]],
	#void stuff
	"Encroaching Void":
	[
		"void things",
		"You suddenly feel surrounded by non-existence",
		[["death_zone", 1, false, "surrounding"]]
	],
	#Skeleton Stuff
	"Feint":
	[
		"skeleton things",
		"This strike looks easy to dodge... weirdly so",
		[["damage", 2, false, "No"], ["safety_dmg_reduc", 0, false, "player_pos"]]
	],
	#unarmed player stuff
	"Punch":
	[
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
	"Full Power Punch":
	[
		"hitting and punching and biting and kicking people",
		"Have you ever punched someone with your life on the line?",
		[["damage", 3, false, "No"], ["damage", 1, true, "No"], ["stun", 1, true, "No"]]
	],
	#standard actions
	"Move Up":
	[
		"standard",
		"Do you really need an explanation of what walking forwards is?",
		[["movement", 1, true, "U"]]
	],
	"Move Down":
	[
		"standard",
		"Do you really need an explanation of what walking backwards is?",
		[["movement", 1, true, "D"]]
	],
	"Move Left":
	[
		"standard",
		"Do you really need an explanation of what walking left is?",
		[["movement", 1, true, "L"]]
	],
	"Move Right":
	[
		"standard",
		"Do you really need an explanation of what walking right is?",
		[["movement", 1, true, "R"]]
	],
	
	#weapon skills (first plan)
	"Shank":
		[
		"knife skills",
		"When one... or I suppose two stabs just aren't enough",
		[["damage", 1, false, "No"], ["damage", 1, false, "No"], ["damage", 1, false, "No"]]
	],
	"Slash":
		[
		"sword skills",
		"Truly, the most basic of basic things you could do",
		[["damage", 3, false, "No"]]
	],
	
	#item effects (maybe also here? Who knows what anything is at this point)
	"Heal":
		[
		"potion stuff",
		"Modern Medicine rules",
		[["heal", 3, true, "No"]]
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
