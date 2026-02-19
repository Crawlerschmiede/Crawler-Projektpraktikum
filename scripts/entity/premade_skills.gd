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
		"effects": [["damage_zone", 2, false, "player_x"]],
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
	"Precise Hit":
	{
		"tree": "skeleton things",
		"description": "This strike looks easy to dodge... like seriously, is it even trying?",
		"effects": [["damage_zone", 1, false, "player_pos"]],
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
	"War Cry":  #buff dmg for next turn, jorin pls implement #it is done
	{
		"tree": "goblin things",
		"description": "More scream, more damage",
		"next_turn_effects": [["damage_buff", 2, true, "duration=2"]],
		"effects": [["prepare", 0, true, "No"]],
		"cooldown": 3  # jorin pls implement enemy cooldown thanks #this one too btw
	},
	#Orc Stuff
	"Big Bonk":
	{
		"tree": "orc things",
		"description": "If in doubt, bonk your enemy.",
		"effects": [["damage", 2, false, "No"], ["danger_dmg_mult", 2, false, "player_pos"]],
		"cooldown": 0
	},
	"War Command":  #buff dmg for next turn, jorin pls implement
	{
		"tree": "orc things",
		"description": "More scream, more damage",
		"effects": [["damage_buff", 2, true, "duration=2"]],
		"cooldown": 2  # jorin pls implement enemy cooldown thanks
	},
	"Ground Stomp":
	{
		"tree": "orc things",
		"description": "The Orc Chief stomps its feet into the ground. The whole ground shakes!",
		"effects": [["damage", 3, false, "No"]],
		"cooldown": 1
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
		"description": "Vines lash out, a thorn scratches your skin. You don't feel so well..",
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
		"description":
		"The ground rumbles as your enemy lets out a deafening screech. Its getting angry ...",
		"effects": [["damage", 1, false, "No"], ["danger_dmg_mult", 2, false, "y=0"]],
		"cooldown": 0
	},
	#wendigo
	# Possible Skills: Mimicry(confusion), Evil that devours (big attack), Claw Slash (normal Attack), Insatiable Hunger (Buff)
	"Claw Slash":
	{
		"tree": "wendigo things",
		"description": "Its huge claws try to slash into your flesh",
		"effects": [["Damage", 2, false, "No"]],
		"cooldown": 0
	},
	"Mimicry":
	{
		"tree": "wendigo things",
		"description":
		"You hear a distorted familiar voice calling for you. From where? Who? You feel dizzy..",
		"effects": [["Stun", 3, false, "No"]],
		"cooldown": 1
	},
	"Evil that devours":
	{
		"tree": "wendigo things",
		"description": "ITS EYES PIERCE INTO YOU.. your body writhes in agony",
		"effects":
		[["Damage", 4, false, "No"], ["danger_dmg_mult", 3, false, "area||rand||rand||2"]],
		"cooldown": 2
	},
	"Insatiable Hunger":  #buff dmg for next turn, jorin pls implement
	{
		"tree": "wendigo things",
		"description":
		"It howls into the void, blood tripping from its teeth. You can feel it getting angrier.. stronger",
		"effects": [["damage_buff", 2, true, "duration=2"]],
		"cooldown": 1  # jorin pls implement enemy cooldown thanks
	},
	# Necromancer Stuff
	# Possible Skills: Green Flames, Life Steal, Domain Expansion, Rise from the dead
	"Green Flames":
	{
		"tree": "necromancer things",
		"description": "Green flames engulf the room",
		"effects": [["Burn", 2, false, "No"], ["danger_dmg_mult", 3, false, "area||rand||rand||2"]],
		"cooldown": 1
	},
	"Life Steal":
	{
		"tree": "necromancer things",
		"description": "The necromancer raises its hand. Its wounds begin to heal, you feel weaker",
		"effects": [["Stun", 2, false, "No"], ["heal", 2, true, "No"]],
		"cooldown": 1
	},
	"Domain Expansion":
	{
		"tree": "necromancer things",
		"description": "Chanting a demonic spell, the room turns to darkness",
		"effects": [["Damage", 4, false, "No"]],
		"cooldown": 2
	},
	"Join the dead":  #buff dmg for next turn, jorin pls implement
	{
		"tree": "necromancer things",
		"description": "",
		"effects": [["Damange", 4, false, "No"], ["Stun", 3, false, "No"]],
		"cooldown": 2
	},
	#unarmed player stuff
	"Punch":
	{
		"tree": "basic",
		"tier": 1,
		"description": "It's a punch... you don't need an explanation",
		"effects": [["damage", 2, false, "No"]],
		"cooldown": 2,
		"conditions": ["unarmed"]
	},
	"Right Pivot":
	{
		"tree": "basic",
		"tier": 2,
		"description": "It's a punch BUT you also take a step to the right, how novel!",
		"effects": [["damage", 1, false, "No"], ["movement", 1, true, "R"]],
		"cooldown": 2
	},
	"Left Pivot":
	{
		"tree": "basic",
		"tier": 2,
		"description": "It's a punch BUT you also take a step to the left, how exciting!",
		"effects": [["damage", 1, false, "No"], ["movement", 1, true, "L"]],
		"cooldown": 2
	},
	"Full Power Punch":
	{
		"tree": "basic",
		"tier": 4,
		"description": "Have you ever punched someone with your life on the line?",
		"effects": [["damage", 3, false, "No"], ["damage", 1, true, "No"], ["stun", 1, true, "No"]],
		"cooldown": 5
	},
	#short ranged weaponry
	"Close and Personal":
	{
		"tree": "Short Ranged Weaponry",
		"tier": 1,
		"description": "Oh damn...",
		"effects": [["damage_buff", 1.5, true, "No"]],
		"passive": true,
		"conditions": ["short_range"]
	},
	"Sly Dodge":
	{
		"tree": "Short Ranged Weaponry",
		"tier": 2,
		"description": "For when you like where you are, but like, not for a few seconds",
		"effects": [["movement", 1, true, "D"]],
		"next_turn_effects": [["movement", 1, true, "U"]],
		"cooldown": 0
	},
	"Stabby Stabby":
	{
		"tree": "Short Ranged Weaponry",
		"tier": 3,
		"description": "Oh shoot...",
		"effects": [["action_bonus", 1, true, "No"]],
		"passive": true,
		"conditions": ["every_x_turns=2"]
	},
	"Extend the Dancefloor":
	{
		"tree": "Short Ranged Weaponry",
		"tier": 4,
		"description":
		# gdlint:ignore = max-line-length
		"It's kinda like a worm on a string, except the worm is a knife and you stab people with it",
		"effects": [["damage_nullification", 1, true, "No"]],
		"passive": true,
		"on_acquisition": [["range_buff", 1, true, "short"]],
		"conditions": ["outside_short_range"]
	},
	"Blade Dance":
	{
		"tree": "Short Ranged Weaponry",
		"tier": 5,
		"description":
		# gdlint:ignore = max-line-length
		"If you can imagine how scary someone running at you with a knife is, imagine how much scarier it'd be if they teleported!",
		"effects": [["movement", 1, true, "rnd_short"], ["damage", 1, false, "No"]],
		"cooldown": 3
	},
	#medium ranged weaponry
	"Middle of the Road":
	{
		"tree": "Medium Ranged Weaponry",
		"tier": 1,
		"description": "Oh damn...",
		"effects": [["damage_buff", 1.5, true, "No"]],
		"passive": true,
		"conditions": ["medium_range"]
	},
	"Two Handed Parry":
	{
		"tree": "Medium Ranged Weaponry",
		"tier": 2,
		"description":
		"Turns out, holding your weapon in two hands actually gives you more strength than with one!",
		"effects": [["safety_dmg_reduc", 0, false, "area||rand||rand||1"]],
		"passive": true,
		"conditions": ["every_x_turns=2"]
	},
	"Overhau":
	{
		"tree": "Medium Ranged Weaponry",
		"tier": 3,
		"description": "Dodging only matters if your opponent has limbs to hit you with",
		"effects": [["damage", 3, false, "No"], ["freeze", 1, true, "No"]],
		"cooldown": 5
	},
	"Plant your Spear":
	{
		"tree": "Mediumg Ranged Weaponry",
		"tier": 4,
		"description":
		# gdlint:ignore = max-line-length
		"Everything in balance, far and close. You can maintain that equilibrium for longer, but have become dependant on it",
		"effects": [["damage_nullification", 1, true, "No"]],
		"passive": true,
		"on_acquisition": [["range_buff", 1, true, "medium"]],
		"conditions": ["outside_medium_range"]
	},
	"Riposte":
	{
		"tree": "Medium Ranged Weaponry",
		"tier": 5,
		"description": "You know who looks extra punchable? People that punch you",
		"effects": [["counter", 1, true, "No"]],
		"passive": true
	},
	#long ranged weaponry
	"Sniper Position":
	{
		"tree": "Long Ranged Weaponry",
		"tier": 1,
		"description": "Oh damn...",
		"effects": [["damage_buff", 1.5, true, "No"]],
		"passive": true,
		"conditions": ["long_range"]
	},
	"Reload":
	{
		"tree": "Long Ranged Weaponry",
		"tier": 2,
		"description":
		"You feel strongly that your opponent would be less scary if you shot them more",
		"effects": [["coolup", 1, true, "No"]],
		"passive": true,
		"conditions": ["every_x_turns=4"]
	},
	"Out of Reach":
	{
		"tree": "Long Ranged Weaponry",
		"tier": 3,
		"description":
		"Dodging is actually way easier when you can describe the enemy as 'all the way over there'",
		"effects": [["dodge_chance", 0.5, true, "No"]],
		"passive": true,
		"conditions": ["every_x_turns=2"]
	},
	"Open Fields":
	{
		"tree": "Long Ranged Weaponry",
		"tier": 4,
		"description":
		# gdlint:ignore = max-line-length
		"You are one with the bow and have mastered ranged combat. Close quarters though? Too scary",
		"effects": [["damage_nullification", 1, true, "No"]],
		"passive": true,
		"on_acquisition": [["range_buff", 1, true, "long"]],
		"conditions": ["outside_long_range"]
	},
	"Fill the Sky":
	{
		"tree": "Long Ranged Weaponry",
		"tier": 5,
		"description":
		"Did you know that shooting our enemy a lot is actually more effective than just once?",
		"effects": [["damage", 1, false, "ramp||consecutive"]],
		"cooldown": 0
	},
	#unarmed skill tree
	"Flying Fists and Feets":
	{
		"tree": "Unarmed",
		"tier": 1,
		"description": "It's impressive how far a kick can reach if you stretch a bit",
		"effects": [["damage_buff", 1.25, true, "overwrite_range"]],
		"passive": true,
		"conditions": ["unarmed"]
	},
	"Sting like a Bee":
	{
		"tree": "Unarmed",
		"tier": 2,
		"description": "Well... it's not a big sting... let's hope your enemy is allergic",
		"effects": [["stun", 3, false, "No"]],
		"cooldown": 4
	},
	"Float like a Butterfly":
	{
		"tree": "unarmed",
		"tier": 3,
		"description":
		# gdlint:ignore = max-line-length
		"God, it pains me to think about just how annoying it must be to try and hit you...",
		"effects": [["movement", 1, true, "conditional--rnd_long||rnd_short"]],
		"cooldown": 3,
		"switch_condition": ["outside_short_range"]
	},
	"Pressure Points":
	{
		"tree": "unarmed",
		"tier": 4,
		"description": "Armour? More like... disarm 'er!... wait that doesn't work at all",
		"effects": [["piercing", 0.2, true, "No"]],
		"passive": true,
		"on_acquisition": [["unarmable", 1, true, "No"]],
	},
	"Elemental Fists":
	{
		"tree": "unarmed",
		"tier": 5,
		"description":
		"They do say punching your opponent square in the face is an elementary technique",
		"effects": [["elementize", "rand", true, "No"]],
		"passive": true
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
		"description": "When one stab just isn't enough",
		"effects": [["damage", 1, false, "No"], ["damage", 1, false, "No"]],
		"cooldown": 2
	},
	"Shoot":
	{
		"tree": "bow skills",
		"description":
		"You feel like, in maybe a couple centuries, this term would hold more weight",
		"effects": [["damage", 1, false, "No"], ["damage", 1, false, "No"]],
		"cooldown": 2
	},
	"Slash":
	{
		"tree": "sword skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 2, false, "No"]],
		"cooldown": 2
	},
	"Stab":
	{
		"tree": "spear skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 2, false, "No"]],
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
	var switch_conditions = []
	if values.has("switch_condition"):
		switch_conditions = values.switch_condition
	print(values)
	var new_skill = Skill.new(
		skill_name, values.tree, values.description, cool, passive, conditions, switch_conditions
	)
	for effect in values.effects:
		new_skill.add_effect(effect[0], effect[1], effect[2], effect[3])
	if values.has("next_turn_effects"):
		for effect in values.next_turn_effects:
			new_skill.add_effect(effect[0], effect[1], effect[2], effect[3], false)
	if values.has("on_acquisition"):
		for effect in values.on_acquisition:
			new_skill.add_immediate_effect(effect[0], effect[1], effect[2], effect[3])
	return new_skill


func get_skills_by_tree(tree_name: String):
	var skills_in_tree = []
	for skill in existing_skills:
		if existing_skills[skill].has("tree"):
			if existing_skills[skill]["tree"] == tree_name:
				skills_in_tree.append([skill, existing_skills[skill]])
		else:
			continue
	return skills_in_tree


func get_tree_explanation(tree_name):
	var skills = get_skills_by_tree(tree_name)
	var explanations = {}
	for skill in skills:
		explanations[skill[0]] = [
			existing_skills[skill[0]].get("description"), get_detailed_description(skill[0])
		]
	return explanations


func get_detailed_description(skill_name) -> String:
	var skill = existing_skills[skill_name]
	var description = skill_name + ": "
	if skill.has("on_acquisition"):
		for effect in skill.on_acquisition:
			description += translate_effect(effect)

	for effect in skill.effects:
		description += translate_effect(effect)
	if skill.has("next_turn_effects"):
		description += " Then, next turn "
		for effect in skill.next_turn_effects:
			description += translate_effect(effect)

	if skill.has("conditions"):
		if len(skill.conditions) == 1:
			description += " if " + skill.conditions[0]
	if skill.has("cooldown"):
		description += " (Cooldown:" + str(skill.cooldown) + ")"
	# actual real description of what the skill does like "Deals 2 physical Damage"
	return description


func translate_effect(effect):
	var to = ""
	var description = ""
	if effect[2]:
		to = "the user"
	else:
		to = "your enemy"
	var val = effect[1]
	var deets = effect[3]
	match effect[0]:
		"damage":
			var start_spec = ""
			var end_spec = ""
			if "fire" in deets:
				start_spec = " fire"
			elif "ice" in deets:
				start_spec = " ice"
			elif "electric" in deets:
				start_spec = " electric"
			elif "earth" in deets:
				start_spec = " earth"
			else:
				start_spec = " physical"
			if "ramp" in deets:
				end_spec = " that ramps up"
				if "consecutive" in deets:
					end_spec += " with every consecutive use "
			description += "Deals " + str(val) + start_spec + " Damage " + "to " + to + end_spec
		"heals":
			description += "Heals " + to + " for " + str(val) + " HP"
		"movement":
			var dir = ""
			match deets:
				"L":
					dir = "left"
				"R":
					dir = "right"
				"U":
					dir = "up"
				"D":
					dir = "down"
			description += "Move " + str(val) + " Tiles " + dir + ""
		"stun":
			description += "Stun " + to + " for " + str(val) + " turns"
		"damage_buff":
			description += "Increase " + to + "'s damage by " + str(100 * (val - 1)) + "%"
		"dodge_chance":
			description += to + " gains a " + str(val * 100) + "% chance of dodging"
		"counter":
			description += to + " deals " + str(val) + " damage back when taking damage"
		"damage_nullification":
			description += "Nullify " + to + "'s damage"
		"coolup":
			description += "Reset the cooldown of " + str(val) + " of " + to + "'s Skills"
		"action_bonus":
			description += to + " gains " + str(val) + " extra actions"
		"freeze":
			description += "Freezes " + to + " for " + str(val) + " turns"
		"safety_dmg_reduc":
			description += "Places " + str(val) + " block tiles"
		"range_buff":
			description += "Extend " + deets + " range"
	description += ". "
	return description
