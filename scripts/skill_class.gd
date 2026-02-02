class_name Skill

extends Resource

@export var name: String
@export var tree_path: String
@export var description: String
@export var cooldown: int
var turns_until_reuse: int = 0
var effects: Array[Effect] = []
var pre_prepared_effects = ["danger_dmg_mult", "safety_dmg_reduc", "death_zone", "heal_zone"]
# TODO: could do with a more sophisticated sorting system later.
var high_prio_effects = ["movement"]


func _init(_name: String, _tree_path: String, _description: String, _cooldown:int):
	name = _name
	tree_path = _tree_path
	description = _description
	cooldown = _cooldown


func prep_skill(user, target, battle):
	var things_that_happened = []
	for effect in effects:
		if effect.type in pre_prepared_effects:
			var stuff = effect.apply(user, target, battle, name)
			for thing in stuff:
				things_that_happened.append(thing)
	return things_that_happened


func activate_skill(user, target, battle):
	turns_until_reuse = cooldown
	var things_that_happened = []
	var stuff = null
	for effect in effects:
		if effect.type in high_prio_effects && !effect.type in pre_prepared_effects:
			stuff = effect.apply(user, target, battle, name)
			for thing in stuff:
				things_that_happened.append(thing)
	for effect in effects:
		if !effect.type in high_prio_effects && !effect.type in pre_prepared_effects:
			stuff = effect.apply(user, target, battle, name)
			print(stuff)
			for thing in stuff:
				things_that_happened.append(thing)
	return things_that_happened


func add_effect(type: String, value: float, targets_self: bool, details: String):
	effects.append(Effect.new(type, value, targets_self, details))
	
func is_activateable()->bool:
	return turns_until_reuse==0
	
func tick_down():
	if turns_until_reuse>0:
		turns_until_reuse =turns_until_reuse-1

class Effect:
	var type: String
	var value: float
	var targets_self: bool
	# For general use (e.g. movement holds "left" / "user input" / etc.)
	var details: String

	func _init(_type: String, _value: float, _targets_self: int, _details: String):
		type = _type
		value = _value
		targets_self = _targets_self
		details = _details

	# gdlint: disable=max-returns
	func apply(user, target, battle, skill_name):
		var messages = []
		var active_placement_effects = battle.tile_modifiers.get(battle.player_gridpos, {})
		print("All mods", battle.tile_modifiers)
		print("Active mods: ", active_placement_effects)
		match type:
			"damage":
				print("Activating damage!")
				var active_dmg = value
				for modifier_name in active_placement_effects:
					var modifier_value = active_placement_effects[modifier_name]

					match modifier_name:
						"dmg_mult_bad":
							if !user.is_player:
								active_dmg *= modifier_value
						"dmg_mult_good":
							if user.is_player:
								active_dmg *= modifier_value
						"dmg_reduc_good":
							if !user.is_player:
								active_dmg *= modifier_value
						"dmg_reduc_bad":
							if user.is_player:
								active_dmg *= modifier_value

				if targets_self:
					messages = user.take_damage(active_dmg)
				else:
					messages = target.take_damage(active_dmg)
				return ["Target " + messages[0] + " from " + skill_name, "Target " + messages[1]]
			"movement":
				print("Activating movement")
				var basic_directions = ["U", "D", "L", "R"]
				if details in basic_directions:
					return [battle.move_player(details, value)]
			"danger_dmg_mult":
				print("Activating danger")
				var duration = 1
				return battle.apply_zones("dmg_mult_", value, details, duration, "bad")
			"poison":
				print("Activating poison!")
				if targets_self:
					messages = user.increase_poison(value)
				else:
					messages = target.increase_poison(value)
				return ["Targets " + messages[0]]
			"stun":
				print("Stunning!")
				if targets_self:
					messages = user.increase_stun(value)
				else:
					messages = target.increase_stun(value)
				return ["Targets " + messages[0]]
			"safety_dmg_reduc":
				print("Activating safety")
				var duration = 1
				return battle.apply_zones("dmg_reduc_", value, details, duration, "good")
			"death_zone":
				print("Activating death")
				var duration = 1
				var direction
				if (targets_self and user.is_player) or (!targets_self and !user.is_player):
					direction = "bad"
				else:
					direction = "good"
				return battle.apply_zones("death_", value, details, duration, direction)
			"heal_zone":
				print("Activating death")
				var duration = 1
				var direction
				if (targets_self and user.is_player) or (!targets_self and !user.is_player):
					direction = "good"
				else:
					direction = "bad"
				return battle.apply_zones("heal_", value, details, duration, direction)
			"heal":
				if targets_self:
					messages = user.heal(value)
				else:
					messages = target.heal(value)

	# gdlint: enable=max-returns
