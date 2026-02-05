class_name MadeSkills

extends Resource

#write skills here as
# name : [skilltree, description, effects, cooldown]
# The effects should be in the format:
# [[type, value, targets_self, details],
#  [same thing for more effects]...]]

# for dmg reduction, 1 means full damage taken and 0 means full immunity
# with float values in between

# as for the cooldowns, they default to 0 if none is given
#for now enemies don't care about cooldowns,
# so either keep enemy skills at cooldown 0 or make them care
# for player cooldowns, because of how the ticking down works, please input them
# 1 higher than you want
# i.e., a cooldown of 2 means it'll be unusable for 1 turn (it counts the turn
# it's used in)
# this is fixable... but just not worth the time, you can all calculate +1 in
# your head

# as for passives, it defaults to being an actve skill if you don't specify,
# I recommend making it explicit regardless, for readability
# (not that I will, do as I say not as I do and so on...)
var existing_skills = {
	#bat stuff
	"Screech":
	{
		"tree": "bat things",
		"description": "AAAAAAAAAAAAAAAAAAAAAAAAAAAA",
		"effects": [["damage", 1, false, "No"], ["danger_dmg_mult", 2, false, "y=0"]],
	},
	"Swoop":
	{
		"tree": "bat things",
		"description":
		"You'd think a bat headbutting you wouldn't hurt that much... " + "you'd be wrong",
		"effects": [["damage", 1, false, "No"], ["danger_dmg_mult", 2, false, "player_x"]],
	},
	"Rabies":
	{
		"tree": "bat things",
		"description": "It's a wild animal. They have this sometimes",
		"effects": [["poison", 2, false, "No"]],
	},
	#void stuff
	"Encroaching Void":
	{
		"tree": "void things",
		"description": "You suddenly feel surrounded by non-existence",
		"effects": [["death_zone", 1, false, "surrounding"]],
		"cooldown": 3
	},
	"Vortex":
	{
		"tree": "void things",
		"description": "A churning maelstrom of... something erupts",
		"effects":
		[["damage", 1, false, "No"], ["danger_dmg_mult", 3, false, "area||rand||rand||2"]],
	},
	#Skeleton Stuff
	"Feint":
	{
		"tree": "skeleton things",
		"description": "This strike looks easy to dodge... weirdly so",
		"effects": [["damage", 2, false, "No"], ["safety_dmg_reduc", 0, false, "player_pos"]],
	},
	"Eye-Flash-Slash":
	{
		"tree": "skeleton things",
		"description": "I promise the flashing eyes are more than just nonsense!",
		"effects": [["prepare", 0, true, "No"]],
		"next_turn_effects": [["damage_buff", 2, true, "duration=2"], ["damage", 1, false, "No"]]
	},
	#Goblin Stuff
	"Bonk":
	{
		"tree": "goblin things",
		"description": "If in doubt, bonk your enemy.",
		"effects": [["damage", 2, false, "No"], ["danger_dmg_mult", 2, false, "player_pos"]],
		"cooldown": 0
	},
	"War Cry":  #buff dmg for next turn, jorin pls implement
	{
		"tree": "goblin things",
		"description": "More scream, more damage",
		"effects": [["buff", 2, true, "No"]],
		"cooldown": 0  # jorin pls implement enemy cooldown thanks
	},
	#Carnivorous Plant skills
	"Vine Slash":
	{
		"tree": "plant things",
		"description": "A sharp vine slashes across the room",
		"effects": [["damage", 2, false, "No"], ["danger_dmg_mult", 2, false, "player_y"]],
		"cooldown": 0
	},
	"Entwine":
	{
		"tree": "plant things",
		"description":
		"Thick vines shoot from the ground at your legs and entwine your body. You are stunned!",
		"effects": [["stun", 2, false, "No"]],
		"cooldown": 0
	},
	"Poison Ivy":
	{
		"tree": "plant things",
		"description": "Vines lash out, a thron scratches your skin. You don't feel so well..",
		"effects": [["poison", 2, false, "No"]],
		"cooldown": 0
	},
	"Herbicide":
	{
		"tree": "plant things",
		"description": "The trap gapes and lashes out trying to tear its teeth into your flesh.",
		"effects": [["Damage", 3, false, "No"], ["Damage", 1, true, "No"]],
		"cooldown": 0
	},
	"Mandrake's Screech":
	{
		"tree": "plant things",
		"desciption":
		"The ground rumbles as your enemy lets out a deafening screech. Its getting angry..",
		"effects": [["damage", 1, false, "No"], ["danger_dmg_mult", 2, false, "y=0"]],
		"cooldown": 0
	},
	#unarmed player stuff
	"Punch":
	{
		"tree": "hitting and punching and biting and kicking people",
		"description": "It's a punch... you don't need an explanation",
		"effects": [["damage", 2, false, "No"]],
		"cooldown": 2
	},
	"Back and Forth":
	{
		"tree": "hitting and punching and biting and kicking people",
		"description": "It's a punch... you don't need an explanation",
		"effects": [["movement", 1, true, "D"]],
		"next_turn_effects": [["movement", 1, true, "U"]],
		"cooldown": 0
	},
	"Right Pivot":
	{
		"tree": "hitting and punching and biting and kicking people",
		"description": "It's a punch BUT you also take a step to the right, how novel!",
		"effects": [["damage", 1, false, "No"], ["movement", 1, true, "R"]],
		"cooldown": 2
	},
	"Left Pivot":
	{
		"tree": "hitting and punching and biting and kicking people",
		"description": "It's a punch BUT you also take a step to the left, how exciting!",
		"effects": [["damage", 1, false, "No"], ["movement", 1, true, "L"]],
		"cooldown": 2
	},
	"Full Power Punch":
	{
		"tree": "hitting and punching and biting and kicking people",
		"description": "Have you ever punched someone with your life on the line?",
		"effects": [["damage", 3, false, "No"], ["damage", 1, true, "No"], ["stun", 1, true, "No"]],
		"cooldown": 5
	},
	"Strong as frick":
	{
		"tree": "hitting and punching and biting and kicking people",
		"description": "Oh damn...",
		"effects": [["damage_buff", 1.5, true, "No"]],
		"passive": true,
		"conditions": ["short_range"]
	},
	"Fast as frick":
	{
		"tree": "hitting and punching and biting and kicking people",
		"description": "Oh shoot...",
		"effects": [["action_bonus", 1, true, "No"]],
		"passive": true,
		"conditions": ["every_x_turns=2"]
	},
	#standard actions
	"Move Up":
	{
		"tree": "standard",
		"description": "Do you really need an explanation of what walking forwards is?",
		"effects": [["movement", 1, true, "U"]],
	},
	"Move Down":
	{
		"tree": "standard",
		"description": "Do you really need an explanation of what walking backwards is?",
		"effects": [["movement", 1, true, "D"]],
	},
	"Move Left":
	{
		"tree": "standard",
		"description": "Do you really need an explanation of what walking left is?",
		"effects": [["movement", 1, true, "L"]],
	},
	"Move Right":
	{
		"tree": "standard",
		"description": "Do you really need an explanation of what walking right is?",
		"effects": [["movement", 1, true, "R"]],
	},
	#weapon skills (first plan)
	"Shank":
	{
		"tree": "knife skills",
		"description": "When one... or I suppose two stabs just aren't enough",
		"effects":
		[["damage", 1, false, "No"], ["damage", 1, false, "No"], ["damage", 1, false, "No"]],
		"cooldown": 2
	},
	"Slash":
	{
		"tree": "sword skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 3, false, "No"]],
		"cooldown": 2
	},
	#item effects (maybe also here? Who knows what anything is at this point)
	"Heal":
	{
		"tree": "potion stuff",
		"description": "Modern Medicine rules",
		"effects": [["heal", 3, true, "No"]]
	},
}


func get_skill(skill_name):
	var values = existing_skills.get(skill_name)
	if values == null:
		return values
	var cool = 0
	if values.has("cooldown"):
		cool = values.cooldown
	var passive = false
	if values.has("passive"):
		passive = values.passive
	var conditions = []
	if values.has("conditions"):
		conditions = values.conditions
	print(skill_name, values.tree, values.description, cool, passive, conditions)
	var new_skill = Skill.new(
		skill_name, values.tree, values.description, cool, passive, conditions
	)
	for effect in values.effects:
		new_skill.add_effect(effect[0], effect[1], effect[2], effect[3])
	if values.has("next_turn_effects"):
		for effect in values.next_turn_effects:
			new_skill.add_effect(effect[0], effect[1], effect[2], effect[3], false)
	return new_skill
