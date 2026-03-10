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
		"effects": [["damage", 1, false, "No"], ["safety_dmg_reduc", 0, false, "player_pos"]],
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
		"effects": [["damage_zone", 2, false, "player_pos"]],
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
		"effects": [["damage_zone", 2, false, "area||player_x||player_y||2"]],
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
		"effects": [["danger_dmg_mult", 2, false, "area||player_x||player_y||4"]],
		"cooldown": 3
	},
	"Club Swing":
	{
		"tree": "orc things",
		"description": "Orc pulls back and swings its club with full force",
		"effects":
		[
			["movement", 1, false, "D"],
			["movement", 1, false, "D"],
			["movement", 1, false, "D"],
			["damage_zone", 3, false, "y=3"],
			["damage_zone", 2, false, "y=4"]
		],
		"cooldown": 2
	},
	#Carnivorous Plant skills
	"Vine Slash":
	{
		"tree": "plant things",
		"description": "A sharp vine slashes across the room",
		"effects": [["damage_zone", 2, false, "player_y"]],
		"cooldown": 0
	},
	"Uproot":
	{
		"tree": "plant things",
		"description": "A vine grabs your leg and pulls you towards the enemy",
		"effects":
		[
			["movement", 1, false, "U"],
			["movement", 1, false, "U"],
			["movement", 1, false, "U"],
			["damage_zone", 3, false, "y=0"],
			["damage_zone", 2, false, "y=1"]
		],
		"cooldown": 2
	},
	"Entwine":
	{
		"tree": "plant things",
		"description":
		"Thick vines shoot from the ground at your legs and entwine your body. You are stunned!",
		"effects": [["stun", 1, false, "No"]],
		"cooldown": 2
	},
	"Poison Ivy":
	{
		"tree": "plant things",
		"description": "Vines lash out, a thorn scratches your skin. You don't feel so well..",
		"effects": [["poison", 2, false, "No"]],
		"cooldown": 2
	},
	"Herbicide":
	{
		"tree": "plant things",
		"description": "The trap gapes and lashes out trying to tear its teeth into your flesh.",
		"effects": [["danger_dmg_mult", 2, false, "area||player_x||player_y||2"]],
		"cooldown": 2
	},
	"Mandrake's Screech":
	{
		"tree": "plant things",
		"description":
		"The ground rumbles as your enemy lets out a deafening screech. Its getting angry ...",
		"effects": [["damage", 1, false, "No"], ["damage_buff", 2, true, "duration=2"]],
		"cooldown": 2
	},
	#wendigo
	# Possible Skills: Mimicry(confusion), Evil that devours (big attack),
	# Claw Slash (normal Attack), Insatiable Hunger (Buff)
	"Claw Slash":
	{
		"tree": "wendigo things",
		"description": "Its huge claws try to slash into your flesh",
		"effects":
		[
			["damage_zone", 2, false, "y=0"],
			["damage_zone", 2, false, "y=2"],
			["damage_zone", 2, false, "y=4"]
		],
		"cooldown": 0
	},
	"Mimicry":
	{
		"tree": "wendigo things",
		"description":
		"You hear a distorted familiar voice calling for you. From where? Who? You feel dizzy..",
		"effects":
		[["movement", 1, false, "U"], ["movement", 1, false, "U"], ["Stun", 2, false, "No"]],
		"cooldown": 3
	},
	"Evil that devours":
	{
		"tree": "wendigo things",
		"description": "ITS EYES PIERCE INTO YOU.. your body writhes in agony",
		"effects": [["death_zone", 1, false, "surrounding"], ["damage_zone", 2, false, "player_x"]],
		"cooldown": 2
	},
	"Insatiable Hunger":  #buff dmg for next turn, jorin pls implement
	{
		"tree": "wendigo things",
		"description":
		(
			"It howls into the void, blood tripping from its teeth. "
			+ "You can feel it getting angrier.. stronger"
		),
		"effects": [["damage_buff", 2, true, "duration=2"]],
		"cooldown": 1  # jorin pls implement enemy cooldown thanks
	},
	# Necromancer Stuff
	# Possible Skills: Green Flames, Life Steal, Domain Expansion, Rise from the dead
	"Green Flames":
	{
		"tree": "necromancer things",
		"description": "Green flames engulf the room",
		"effects":
		[
			["burn", 2, false, "No"],
			["damage_zone", 2, false, "y=0"],
			["damage_zone", 2, false, "y=2"],
			["damage_zone", 2, false, "y=4"],
			["damage_zone", 2, false, "x=0"],
			["damage_zone", 2, false, "x=2"],
			["damage_zone", 2, false, "x=4"]
		],
		"cooldown": 1
	},
	"Life Steal":
	{
		"tree": "necromancer things",
		"description": "The necromancer raises its hand. Its wounds begin to heal, you feel weaker",
		"effects": [["Stun", 1, false, "No"], ["heal", 2, true, "No"]],
		"cooldown": 3
	},
	"Domain Expansion":
	{
		"tree": "necromancer things",
		"description": "Chanting a demonic spell, the room turns to darkness",
		"effects": [["damage_zone", 2, false, "area||2||2||3"]],
		"cooldown": 3
	},
	"Join the dead":
	{
		"tree": "necromancer things",
		"description": "",
		"effects":
		[["death_zone", 1, false, "player_pos"], ["damage_zone", 2, false, "surrounding"]],
		"cooldown": 2
	},
	"OBEY":
	{
		"tree": "necromancer things",
		"description": "Know your place and KNEEL",
		"effects":
		[
			["movement", 1, false, "D"],
			["movement", 1, false, "D"],
			["movement", 1, false, "D"],
			["Stun", 1, false, "No"]
		],
		"cooldown": 2
	},
	"BOW TO YOUR MASTER":
	{
		"tree": "necromancer things",
		"description": "A dark force drags you towards your enemie. This might be your end.",
		"effects":
		[
			["movement", 1, false, "U"],
			["movement", 1, false, "U"],
			["movement", 1, false, "U"],
			["movement", 1, false, "U"],
			["death_zone", 1, false, "player_y"]
		],
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
		"conditions": ["unarmed"],
		"full_description": "Deal 2 damage to your opponent."
	},
	"Full Power Punch":
	{
		"tree": "basic",
		"tier": 4,
		"description": "Have you ever punched someone with your life on the line?",
		"effects": [["damage", 3, false, "No"], ["damage", 1, true, "No"], ["stun", 2, true, "No"]],
		"cooldown": 5,
		"full_description":
		"Deal 3 damage to your opponent, but also deal 1 damage to yourself and become stunned."
	},
	#short ranged weaponry
	"Close and Personal":
	{
		"tree": "Short-Ranged-Weaponry",
		"tier": 1,
		"description": "Oh damn...",
		"effects": [["damage_buff", 1.5, true, "No"]],
		"passive": true,
		"conditions": ["short_range"],
		"full_description": "Increases your damage by 50% while in short range."
	},
	"Sly Dodge":
	{
		"tree": "Short-Ranged-Weaponry",
		"tier": 2,
		"description": "For when you like where you are, but like, not for a few seconds",
		"effects": [["movement", 1, true, "D"]],
		"next_turn_effects": [["movement", 1, true, "U"]],
		"cooldown": 0,
		"full_description": "Move backwards then move forwards next turn."
	},
	"Stabby Stabby":
	{
		"tree": "Short-Ranged-Weaponry",
		"tier": 3,
		"description": "Oh shoot...",
		"effects": [["action_bonus", 1, true, "No"]],
		"passive": true,
		"conditions": ["every_x_turns=2"],
		"full_description": "Gain an extra action every other turn."
	},
	"Extend the Dancefloor":
	{
		"tree": "Short-Ranged-Weaponry",
		"tier": 4,
		"description":
		# gdlint:ignore = max-line-length
		"It's kinda like a worm on a string, except the worm is a knife and you stab people with it",
		"effects": [["damage_nullification", 1, true, "No"]],
		"passive": true,
		"on_acquisition": [["range_buff", 1, true, "short"]],
		"conditions": ["outside_short_range"],
		"full_description":
		"The second front row also counts as short range. Deal no damage outside of short range."
	},
	"Blade Dance":
	{
		"tree": "Short-Ranged-Weaponry",
		"tier": 5,
		"description":
		# gdlint:ignore = max-line-length
		"If you can imagine how scary someone running at you with a knife is, imagine how much scarier it'd be if they teleported!",
		"effects": [["movement", 1, true, "rnd|short"], ["damage", 1, false, "No"]],
		"cooldown": 3,
		"full_description": "Move into short range and deal 1 damage."
	},
	#medium ranged weaponry
	"Middle of the Road":
	{
		"tree": "Medium-Ranged-Weaponry",
		"tier": 1,
		"description": "Oh damn...",
		"effects": [["damage_buff", 1.5, true, "No"]],
		"passive": true,
		"conditions": ["medium_range"],
		"full_description": "Increases your damage by 50% while in medium range."
	},
	"Two Handed Parry":
	{
		"tree": "Medium-Ranged-Weaponry",
		"tier": 2,
		"description":
		"Turns out, holding your weapon in two hands actually gives you more strength than with one!",
		"effects": [["safety_dmg_reduc", 0, false, "area||rand||rand||1"]],
		"passive": true,
		"conditions": ["every_x_turns=2"],
		"full_description": "Spawn a block tile randomly on the grid every other turn."
	},
	"Overhau":
	{
		"tree": "Medium-Ranged-Weaponry",
		"tier": 3,
		"description": "Dodging only matters if your opponent has limbs to hit you with",
		"effects": [["damage", 5, false, "No"], ["freeze", 1, true, "No"]],
		"cooldown": 5,
		"full_description": "Deal 5 damage, but become frozen in place next turn"
	},
	"Plant your Spear":
	{
		"tree": "Medium-Ranged-Weaponry",
		"tier": 4,
		"description":
		# gdlint:ignore = max-line-length
		"Everything in balance, far and close. You can maintain that equilibrium for longer, but have become dependant on it",
		"effects": [["damage_nullification", 1, true, "No"]],
		"passive": true,
		"on_acquisition": [["range_buff", 1, true, "medium"]],
		"conditions": ["outside_medium_range"],
		"full_description":
		"Additional rows will count as medium range, but you won't deal damage outside of medium range"
	},
	"Riposte":
	{
		"tree": "Medium-Ranged-Weaponry",
		"tier": 5,
		"description": "You know who looks extra punchable? People that punch you",
		"effects": [["counter", 1, true, "No"]],
		"passive": true,
		"full_description":
		"Deal 1 damage after getting hit. Deal 2 instead if the hit was critical"
	},
	#long ranged weaponry
	"Sniper Position":
	{
		"tree": "Long-Ranged-Weaponry",
		"tier": 1,
		"description": "Oh damn...",
		"effects": [["damage_buff", 1.5, true, "No"]],
		"passive": true,
		"conditions": ["long_range"],
		"full_description": "Increases your damage by 50% when in long range"
	},
	"Reload":
	{
		"tree": "Long-Ranged-Weaponry",
		"tier": 2,
		"description":
		"You feel strongly that your opponent would be less scary if you shot them more",
		"effects": [["coolup", 1, true, "No"]],
		"passive": true,
		"conditions": ["every_x_turns=4"],
		"full_description": "Reset the cooldown of a random skill every 4 turns"
	},
	"Out of Reach":
	{
		"tree": "Long-Ranged-Weaponry",
		"tier": 3,
		"description":
		"Dodging is actually way easier when you can describe the enemy as 'all the way over there'",
		"effects": [["dodge_chance", 0.5, true, "No"]],
		"passive": true,
		"conditions": ["every_x_turns=2"],
		"full_description": "Gain a 50% dodge chance every other turn while in long range"
	},
	"Open Fields":
	{
		"tree": "Long-Ranged-Weaponry",
		"tier": 4,
		"description":
		# gdlint:ignore = max-line-length
		"You are one with the bow and have mastered ranged combat. Close quarters though? Too scary",
		"effects": [["damage_nullification", 1, true, "No"]],
		"passive": true,
		"on_acquisition": [["range_buff", 1, true, "long"]],
		"conditions": ["outside_long_range"],
		"full_description":
		"The second to last row will also count as long range, but you will deal no damage outside of long range"
	},
	"Fill the Sky":
	{
		"tree": "Long-Ranged-Weaponry",
		"tier": 5,
		"description":
		"Did you know that shooting our enemy a lot is actually more effective than just once?",
		"effects": [["damage", 1, false, "ramp||consecutive"]],
		"cooldown": 0,
		"full_description": "Deal 1 damage. +1 Damage per consecutive use"
	},
	#unarmed skill tree
	"Flying Fists and Feets":
	{
		"tree": "Unarmed-Combat",
		"tier": 1,
		"description": "It's impressive how far a kick can reach if you stretch a bit",
		"effects": [["damage_buff", 1.25, true, "overwrite_range"]],
		"passive": true,
		"conditions": ["unarmed"],
		"full_description": "Deal 25% more damage while unarmed"
	},
	"Sting like a Bee":
	{
		"tree": "Unarmed-Combat",
		"tier": 2,
		"description": "Well... it's not a big sting... let's hope your enemy is allergic",
		"effects": [["stun", 3, false, "No"]],
		"cooldown": 4,
		"full_description": "Stun your opponent for 3 turns"
	},
	"Float like a Butterfly":
	{
		"tree": "Unarmed-Combat",
		"tier": 3,
		"description":
		# gdlint:ignore = max-line-length
		"God, it pains me to think about just how annoying it must be to try and hit you...",
		"effects": [["movement", 1, true, "conditional--rnd|long||rnd|short"]],
		"cooldown": 3,
		"switch_condition": ["outside_short_range"],
		"full_description":
		"Move into short range. Move into long range instead if you are in short range"
	},
	"Pressure Points":
	{
		"tree": "Unarmed-Combat",
		"tier": 4,
		"description": "Armour? More like... disarm 'er!... wait that doesn't work at all",
		"effects": [["piercing", 0.2, true, "No"]],
		"passive": true,
		"on_acquisition": [["unarmable", 1, true, "No"]],
		"full_description": "Negate 20% of enemy's resistances. YOu can no longer use weapons"
	},
	"Elemental Fists":
	{
		"tree": "Unarmed-Combat",
		"tier": 5,
		"description":
		"They do say punching your opponent square in the face is an elementary technique",
		"effects": [["elementize", "rand", true, "No"]],
		"passive": true,
		"full_description": "Your attacks gain a random element your opponent is weak against"
	},
	"Right Pivot":
	{
		"tree": "Rogue",
		"tier": 1,
		"description": "It's a punch BUT you also take a step to the right, how novel!",
		"effects": [["damage", 1, false, "No"], ["movement", 1, true, "R"]],
		"cooldown": 2,
		"full_description": "Deal 1 damage and move right"
	},
	"Left Pivot":
	{
		"tree": "Rogue",
		"tier": 1,
		"description": "It's a punch BUT you also take a step to the left, how exciting!",
		"effects": [["damage", 1, false, "No"], ["movement", 1, true, "L"]],
		"cooldown": 2,
		"full_description": "Deal 1 damage and move left"
	},
	"Assassination":
	{
		"tree": "Rogue",
		"tier": 2,
		"description":
		"It's surprising just how much easier it is to stab people when they don't see it coming",
		"effects": [["damage_buff", 2, true, "No"]],
		"passive": true,
		"conditions": ["lost_after||effect_happened-damage-1"],
		"full_description": "Your first attack each combat deals double damage"
	},
	# This one triggers twice for some reason.
	# Damage is halved here as a practical workaround.
	"Run 'n Gun":
	{
		"tree": "Rogue",
		"tier": 3,
		"description":
		"Running around so much, you keep dropping your knives. Luckily, they keep falling into your opponent!",
		"effects": [["damage", 1, false, "No"]],
		"passive": true,
		"conditions": ["effect_happened_every-movement-2"],
		"full_description": "Deal 1 damage every other time you move"
	},
	"Reckless Abandon":
	{
		"tree": "Rogue",
		"tier": 4,
		"description":
		"Some say you're 'squishy' and 'a glass cannon', well, not after you kill them they don't!",
		"effects": [["damage_buff", 1.5, true, "No"], ["damage_buff", 1.5, false, "No"]],
		"passive": true,
		"full_description": "Increase damage taken and dealt by 50%"
	},
	"Reckless Acrobatics":
	{
		"tree": "Rogue",
		"tier": 5,
		"description":
		"Turns out, taking a second step after the first one: not as difficult as you may think!",
		"effects":
		[
			["damage", 1, false, "No"],
			["movement", 1, true, "input"],
			["movement", 1, true, "input"]
		],
		"full_description": "Deal 1 damage, then move twice via input"
	},
	#warrior skilltree
	"Shields Up":
	{
		"tree": "Warrior",
		"tier": 1,
		"description": "You have a MASSIVE shield, now, if only it wasn't so damn heavy...",
		"effects": [["safety_dmg_reduc", 0, false, "area||rand||rand||2"]],
		"passive": true,
		"conditions": ["every_x_turns=5"],
		"full_description": "Add a big safe area to the grid every 5 turns"
	},
	"Buckler Bash":
	{
		"tree": "Warrior",
		"tier": 2,
		"description": "That heavy shield hurts more than expected when it hits.",
		"effects": [["damage", 1, false, "conditional--No||dmg_boost=3"]],
		"cooldown": 3,
		"switch_condition": ["on_tile=dmg_reduc_good"],
		"full_description": "Deal 1 damage. +3 Damage while on a block tile"
	},
	"Immovable Object":
	{
		"tree": "Warrior",
		"tier": 3,
		"description":
		"Ok, good news, apparently the sheer weight of your shield is also messing up your opponents!",
		"effects": [["cannot_move", 0, false, "No"]],
		"passive": true,
		"full_description": "Enemies cannot move you"
	},
	"Super Heavy Armour":
	{
		"tree": "Warrior",
		"tier": 4,
		"description": "Armor is basically a wearable shield, if you mind the gaps.",
		"effects": [["add_zone_duration", 1, true, "No"], ["damage_buff", 1.5, false, "No"]],
		"passive": true,
		"full_description": "Safe zones you place last longer. You take 50% more damage"
	},
	"Sprint to cover":
	{
		"tree": "Warrior",
		"tier": 5,
		"description": "Armor can protect you, but only if you reach cover in time.",
		"effects": [["movement", 1, true, "rnd|dmg_reduc_good"]],
		"cooldown": 5,
		"full_description": "Move to the next safe zone"
	},
	#cleric skilltree
	"Nature's Blessing":
	{
		"tree": "Cleric",
		"tier": 1,
		"description": "Divine and/or natural energies flow through you, soothing your wounds",
		"effects": [["heal", 1, true, "No"]],
		"passive": true,
		"conditions": ["every_x_turns=2"],
		"full_description": "heal 1 HP every other turn"
	},
	"Combat Medic":
	{
		"tree": "Cleric",
		"tier": 2,
		"description": "Simple soothing is not enough anymore, so you push the pain away directly.",
		"effects": [["heal", 3, true, "No"]],
		"cooldown": 5,
		"full_description": "Heal 3 HP"
	},
	"Confuse thy enemy":
	{
		"tree": "Cleric",
		"tier": 3,
		"description": "Medicine is your thing now, so your enemies get a taste of it too.",
		"effects": [["confuse", 3, false, "duration=2"]],
		"cooldown": 5,
		"full_description": "Confuse your enemy, addinga  chance for it to hurt itself"
	},
	"Leech Life":
	{
		"tree": "Cleric",
		"tier": 4,
		"description": "Relief is not enough anymore, so you redirect your pain onto others.",
		"effects":
		[["leeching", 4, true, "No"], ["damage", 2, true, "ignoredef||undodgeable||plain"]],
		"passive": true,
		"full_description": "Heal 4 HP every time you attack. Take 2 damage every turn"
	},
	"Nature says NO!!!":
	{
		"tree": "Cleric",
		"tier": 5,
		"description": "You mastered pain and weaponize it to stop your opponent's bad ideas.",
		"effects": [["deter", 1, false, "No"]],
		"cooldown": 5,
		"full_description":
		"Change what attack your enemy is about to do. Doesn't work if only 1 is available"
	},
	#mage skilltree
	"Adaptable":
	{
		"tree": "Mage",
		"tier": 1,
		"description": "Elemental power flows through your veins",
		"effects": [["element_buff", 1.25, true, "all"]],
		"passive": true,
		"full_description": "Deal 25% more damage with attacks that aren't physical."
	},
	#yes, as it stands this skill is literally just gambling
	#don't tell me that's not peak
	#(can also copy enemy skills, which is cool but might also crash things(maybe)
	#(I'll keep it as is for now, but it's an easy fix if it causes trouble)
	"Your powers are mine!":
	{
		"tree": "Mage",
		"tier": 2,
		"description": "*Tips up glasses* Fool, I have already studied all possible moves!",
		"effects": [["random", 1, true, "any"]],
		"cooldown": 2,
		"full_description": "Use any possible skill at random"
	},
	"Mastery of time":
	{
		"tree": "Mage",
		"tier": 3,
		"description":
		"Damage over time, huh? But have we ever considered damage UNDER time? Didn't think so",
		"effects": [["alter_recovery", 0.5, false, "No"]],
		"passive": true,
		"conditions": ["lost_after||effect_happened-alter_recovery-1"],
		"full_description": "Status effects on your enemy last twice as long"
	},
	"Elemental insights":
	{
		"tree": "Mage",
		"tier": 4,
		"description": "You perceive enemy elemental flaws, but your focus also empowers them.",
		"effects":
		[
			["set_resistance", -1, false, "random|elemental"],
			["set_resistance", 0.5, false, "random|elemental"]
		],
		"passive": true,
		"conditions": ["lost_after||effect_happened-alter_recovery-1"],
		"full_description":
		"Your enemy will take double damage by attacks of a random element, but half damage by attacks of another random element"
	},
	"Wretched Deluge":
	{
		"tree": "Mage",
		"tier": 5,
		"description": "You unleash a wave of mixed elements and drown your target in chaos.",
		"effects":
		[
			["damage", 1, false, "fire"],
			["damage", 1, false, "earth"],
			["damage", 1, false, "ice"],
			["damage", 1, false, "electric"],
			["poison", 2, false, "No"],
			["stun", 2, false, "No"]
		],
		"cooldown": 8,
		"full_description":
		"Deal 1 damage of every element, apply 2 poison to your enemy and stun them for 2 turns"
	},
	#standard actions
	"Move Up":
	{
		"tree": "standard",
		"description": "Do you really need an explanation of what walking forwards is?",
		"effects": [["movement", 1, true, "U"]],
		"full_description": "Move upwards"
	},
	"Move Down":
	{
		"tree": "standard",
		"description": "Do you really need an explanation of what walking backwards is?",
		"effects": [["movement", 1, true, "D"]],
		"full_description": "Move downwards"
	},
	"Move Left":
	{
		"tree": "standard",
		"description": "Do you really need an explanation of what walking left is?",
		"effects": [["movement", 1, true, "L"]],
		"full_description": "Move left"
	},
	"Move Right":
	{
		"tree": "standard",
		"description": "Do you really need an explanation of what walking right is?",
		"effects": [["movement", 1, true, "R"]],
		"full_description": "Move right"
	},
	"Extinguish":
	{
		"tree": "basic",
		"tier": 1,
		"description": "This is fine",
		"effects": [["extinguish", 1, true, "conditional--0.5||1"]],
		"conditions": ["burning"],
		#the switch condition doesn't fucking work if used on a second skill
		#speed over perfection people!
		"switch_condition": ["skill_happened_consecutive-Extinguish-1"],
		"full_description": "Remove half the fire procs on you. Remove all if used consecutively"
	},
	#weapon skills (first plan)
	#is the +1 +2 mechanic maybe the cheapest possible option?
	#Yeah sure
	#Does it work?
	#...
	#Presumably
	#...
	"Shank":
	{
		"tree": "knife skills",
		"description": "When one stab just isn't enough",
		"effects":
		[
			["damage", 1, false, "No"],
			["poison", 2, false, "No"],
		],
		"cooldown": 2
	},
	"Shank +1":
	{
		"tree": "knife skills",
		"description": "When one stab just isn't enough",
		"effects":
		[
			["damage", 2, false, "No"],
			["poison", 3, false, "No"],
		],
		"cooldown": 2
	},
	"Shank +2":
	{
		"tree": "knife skills",
		"description": "When one stab just isn't enough",
		"effects":
		[
			["damage", 2, false, "No"],
			["damage", 2, false, "No"],
			["poison", 3, false, "No"],
		],
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
	"Shoot +1":
	{
		"tree": "bow skills",
		"description":
		"You feel like, in maybe a couple centuries, this term would hold more weight",
		"effects":
		[["damage", 1, false, "No"], ["damage", 1, false, "No"], ["damage", 1, false, "No"]],
		"cooldown": 2
	},
	"Shoot +2":
	{
		"tree": "bow skills",
		"description":
		"You feel like, in maybe a couple centuries, this term would hold more weight",
		"effects":
		[
			["damage", 1, false, "No"],
			["damage", 1, false, "No"],
			["damage", 1, false, "No"],
			["damage", 3, false, "No"]
		],
		"cooldown": 2
	},
	"Fire Bolt":
	{
		"tree": "bow skills",
		"description":
		"You feel like, in maybe a couple centuries, this term would hold more weight",
		"effects": [["damage", 3, false, "pierce||0.1"]],
		"cooldown": 3
	},
	"Fire Bolt +1":
	{
		"tree": "bow skills",
		"description":
		"You feel like, in maybe a couple centuries, this term would hold more weight",
		"effects": [["damage", 4, false, "pierce||0.1"]],
		"cooldown": 3
	},
	"Fire Bolt +2":
	{
		"tree": "bow skills",
		"description":
		"You feel like, in maybe a couple centuries, this term would hold more weight",
		"effects": [["damage", 5, false, "pierce||0.2"]],
		"cooldown": 3
	},
	"Cast":
	{
		"tree": "wand skills",
		"description":
		"You feel like, in maybe a couple centuries, this term would hold more weight",
		"effects": [["damage", 2, false, "fire"]],
		"cooldown": 2
	},
	"Cast +1":
	{
		"tree": "wand skills",
		"description":
		"You feel like, in maybe a couple centuries, this term would hold more weight",
		"effects":
		[
			["damage", 1, false, "fire"],
			["damage", 1, false, "electric"],
		],
		"cooldown": 2
	},
	"Cast +2":
	{
		"tree": "wand skills",
		"description":
		"You feel like, in maybe a couple centuries, this term would hold more weight",
		"effects":
		[
			["damage", 2, false, "fire"],
			["damage", 2, false, "electric"],
		],
		"cooldown": 2
	},
	"Throw":
	{
		"tree": "throwing knife skills",
		"description": "As in 'the weapon', not 'the game' (wait, what game?)",
		"effects":
		[
			["damage", 1, false, "No"],
			["poison", 2, false, "No"],
		],
		"cooldown": 2
	},
	"Throw +1":
	{
		"tree": "throwing knife skills",
		"description": "As in 'the weapon', not 'the game' (wait, what game?)",
		"effects":
		[
			["damage", 2, false, "No"],
			["poison", 3, false, "No"],
		],
		"cooldown": 2
	},
	"Throw +2":
	{
		"tree": "throwing knife skills",
		"description": "As in 'the weapon', not 'the game' (wait, what game?)",
		"effects":
		[
			["damage", 3, false, "No"],
			["poison", 4, false, "No"],
		],
		"cooldown": 2
	},
	"Slash":
	{
		"tree": "sword skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 2, false, "No"]],
		"cooldown": 2
	},
	"Slash +1":
	{
		"tree": "sword skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 3, false, "No"]],
		"cooldown": 2
	},
	"Slash +2":
	{
		"tree": "sword skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 4, false, "No"]],
		"cooldown": 2
	},
	"Stab":
	{
		"tree": "spear skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 2, false, "No"]],
		"cooldown": 2
	},
	"Stab +1":
	{
		"tree": "spear skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 2, false, "pierce||0.1"]],
		"cooldown": 2
	},
	"Stab +2":
	{
		"tree": "spear skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 3, false, "pierce||0.1"]],
		"cooldown": 2
	},
	"Bash":
	{
		"tree": "arm skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 1, false, "No"], ["movement", 1, true, "U"]],
		"cooldown": 2
	},
	"Bash +1":
	{
		"tree": "arm skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 2, false, "No"], ["movement", 1, true, "U"]],
		"cooldown": 2
	},
	"Bash +2":
	{
		"tree": "arm skills",
		"description": "Truly, the most basic of basic things you could do",
		"effects": [["damage", 3, false, "No"], ["movement", 1, true, "U"]],
		"cooldown": 2
	},
	#item effects (maybe also here? Who knows what anything is at this point)
	"Drink":
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


func get_skills_by_condition(conditions: Dictionary):
	var applicable_skills = []
	for skill in existing_skills:
		var tested = existing_skills[skill]
		for condition in conditions:
			var val = tested.get(condition, null)
			if val != null:
				if val == conditions[condition]:
					applicable_skills.append(skill)
			else:
				applicable_skills.append(skill)
	return applicable_skills


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

	return skill.get("full_description", "No description available")
