class_name MadeSkills

extends Resource

#write skills here as
# name : [skilltree, description, effects, cooldown]
# The effects should be in the format:
# [[type, value, targets_self, details], [same thing for more effects]...]]

# for dmg reduction, 1 means full damage taken and 0 means full immunity with float values in between

# as for the cooldowns, for now enemies don't care about cooldowns, 
# so either keep enemy skills at cooldown 0 or make them care
# for player cooldowns, because of how the ticking down works, please input them 1 higher than you want
# i.e., a cooldown of 2 means it'll be unusable for 1 turn (it counts the turn it's used in)
# this is fixable... but just not worth the time, you can all calculate +1 in your head
var existing_skills = {
	#bat stuff
	"Screech":
	[
		"bat things",
		"AAAAAAAAAAAAAAAAAAAAAAAAAAAA",
		[["damage", 1, false, "No"], ["danger_dmg_mult", 2, false, "y=0"]],
		0
	],
	"Swoop":
	[
		"bat things",
		"You'd think a bat headbutting you wouldn't hurt that much... you'd be wrong",
		[["damage", 1, false, "No"], ["danger_dmg_mult", 2, false, "player_x"]],
		0
	],
	"Rabies":
	["bat things", "It's a wild animal. They have this sometimes", [["poison", 2, false, "No"]], 0],
	#void stuff
	"Encroaching Void":
	[
		"void things",
		"You suddenly feel surrounded by non-existence",
		[["death_zone", 1, false, "surrounding"]], 0
	],
	#Skeleton Stuff
	"Feint":
	[
		"skeleton things",
		"This strike looks easy to dodge... weirdly so",
		[["damage", 2, false, "No"], ["safety_dmg_reduc", 0, false, "player_pos"]],
		0
	],
	#Goblin Stuff
	"Bonk":
	[
		"goblin things",
		"If in doubt, bonk your enemy.",
		[["damage", 2, false, "No"], ["danger_dmg_mult", 2, false, "player_pos"]],
		0
	],
	"War Cry": #buff dmg for next turn, jorin pls implement
	[
		"goblin things",
		"More scream, more damage",
		[["buff", 2, true, "No"]],
		0 # jorin pls implement enemy cooldown thanks
	],
	#unarmed player stuff
	"Punch":
	[
		"hitting and punching and biting and kicking people",
		"It's a punch... you don't need an explanation",
		[["damage", 2, false, "No"]],
		2
	],
	"Right Pivot":
	[
		"hitting and punching and biting and kicking people",
		"It's a punch BUT you also take a step to the right, how novel!",
		[["damage", 1, false, "No"], ["movement", 1, true, "R"]],
		2
	],
	"Left Pivot":
	[
		"hitting and punching and biting and kicking people",
		"It's a punch BUT you also take a step to the left, how exciting!",
		[["damage", 1, false, "No"], ["movement", 1, true, "L"]],
		2
	],
	"Full Power Punch":
	[
		"hitting and punching and biting and kicking people",
		"Have you ever punched someone with your life on the line?",
		[["damage", 3, false, "No"], ["damage", 1, true, "No"], ["stun", 1, true, "No"]],
		5
	],
	#standard actions
	"Move Up":
	[
		"standard",
		"Do you really need an explanation of what walking forwards is?",
		[["movement", 1, true, "U"]],
		0
	],
	"Move Down":
	[
		"standard",
		"Do you really need an explanation of what walking backwards is?",
		[["movement", 1, true, "D"]],
		0
	],
	"Move Left":
	[
		"standard",
		"Do you really need an explanation of what walking left is?",
		[["movement", 1, true, "L"]],
		0
	],
	"Move Right":
	[
		"standard",
		"Do you really need an explanation of what walking right is?",
		[["movement", 1, true, "R"]],
		0
	],
	#weapon skills (first plan)
	"Shank":
	[
		"knife skills",
		"When one... or I suppose two stabs just aren't enough",
		[["damage", 1, false, "No"], ["damage", 1, false, "No"], ["damage", 1, false, "No"]],
		0
	],
	"Slash":
	[
		"sword skills",
		"Truly, the most basic of basic things you could do",
		[["damage", 3, false, "No"]],
		0
	],
	#item effects (maybe also here? Who knows what anything is at this point)
	"Heal": ["potion stuff", "Modern Medicine rules", [["heal", 3, true, "No"]],0],
}


func get_skill(skill_name):
	var values = existing_skills.get(skill_name)
	if values == null:
		return values
	var new_skill = Skill.new(skill_name, values[0], values[1], values[3])
	for effect in values[2]:
		new_skill.add_effect(effect[0], effect[1], effect[2], effect[3])
	return new_skill
