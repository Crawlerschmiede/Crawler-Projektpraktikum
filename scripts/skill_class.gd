class_name Skill

extends Resource

@export var name: String
@export var tree_path: String
@export var description: String
@export var cooldown: int
@export var is_passive: bool
@export var conditions: Array
var turns_until_reuse: int = 0
var effects: Array[Effect] = []
var second_turn_effects: Array[Effect] = []
var pre_prepared_effects = ["danger_dmg_mult", "safety_dmg_reduc", "death_zone", "heal_zone"]
# TODO: could do with a more sophisticated sorting system later.
var high_prio_effects = ["movement"]

var last_user = null
var last_target = null
var last_battle = null


func _init(
	_name: String,
	_tree_path: String,
	_description: String,
	_cooldown: int,
	_is_passive: bool,
	_conditions: Array
):
	name = _name
	tree_path = _tree_path
	description = _description
	cooldown = _cooldown
	is_passive = _is_passive
	conditions = _conditions


func prep_skill(user, target, battle):
	var things_that_happened = []
	for effect in effects:
		if effect.type in pre_prepared_effects:
			var stuff = effect.apply(user, target, battle, name)
			for thing in stuff:
				things_that_happened.append(thing)
	return things_that_happened


func activate_skill(user, target, battle, depth = 0):
	turns_until_reuse = cooldown
	var things_that_happened = []
	var stuff = null
	for effect in effects:
		if effect.type in high_prio_effects && !effect.type in pre_prepared_effects:
			stuff = effect.apply(user, target, battle, name, depth)
			for thing in stuff:
				things_that_happened.append(thing)
	for effect in effects:
		if !effect.type in high_prio_effects && !effect.type in pre_prepared_effects:
			stuff = effect.apply(user, target, battle, name, depth)
			for thing in stuff:
				things_that_happened.append(thing)
	if len(second_turn_effects)!=0:
		last_user=user
		last_target=target
		last_battle=battle
		battle.next_turn.append(self)
	return things_that_happened

func activate_followup():
	print("Activating followup to "+name)
	var depth = 0
	var things_that_happened = []
	things_that_happened.append("The preparations pay off!")
	var stuff = null
	for effect in second_turn_effects:
		if effect.type in high_prio_effects && !effect.type in pre_prepared_effects:
			stuff = effect.apply(last_user, last_target, last_battle, name, depth)
			for thing in stuff:
				things_that_happened.append(thing)
	for effect in second_turn_effects:
		if !effect.type in high_prio_effects && !effect.type in pre_prepared_effects:
			stuff = effect.apply(last_user, last_target, last_battle, name, depth)
			for thing in stuff:
				things_that_happened.append(thing)
	return things_that_happened


func add_effect(type: String, value: float, targets_self: bool, details: String, first_turn:bool=true):
	var eff := Effect.new(type, value, targets_self, details)
	if first_turn:
		effects.append(eff)
	else:
		second_turn_effects.append(eff)

func is_activateable(battle=null)->bool:
	var activateable = true
	if not turns_until_reuse==0:
		activateable=false
	if not battle==null:
		for condition in conditions:
			if not condition_met(condition, battle):
				activateable=false
	return activateable


func tick_down():
	if turns_until_reuse > 0:
		turns_until_reuse = turns_until_reuse - 1


func condition_met(condition_name, battle) -> bool:
	var is_met = true
	match condition_name:
		"short_range":
			# TODO: the whole [0,1] thing should come from a variable to become
			# variable.
			is_met = battle.is_player_in_range([0, 1])
		"medium_range":
			is_met = battle.is_player_in_range([2, 2])
		"long_range":
			is_met = battle.is_player_in_range([3, 4])
	print("Condition " + condition_name + " is met? " + str(is_met))
	return is_met

func deactivate(who):
	who.deactivate_buff(name)


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

	func _safe_invoke(obj, method_name: String, args := []):
		# Return a safe default (empty array) if the object is null/freed/missing method.
		if obj == null:
			print("Warning: safe_invoke - null object for method:", method_name)
			return []
		# If it's an Object, check instance validity (prevents 'previously freed')
		if typeof(obj) == TYPE_OBJECT and not is_instance_valid(obj):
			print("Warning: safe_invoke - instance not valid (freed) for method:", method_name)
			return []
		if not obj.has_method(method_name):
			print("Warning: safe_invoke - missing method", method_name, "on", obj)
			return []
		return obj.callv(method_name, args)

	# gdlint: disable=max-returns
	func apply(user, target, battle, skill_name, depth = 0):
		var messages = []
		var ret = []
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

				for alteration in user.alterations:
					if user.alterations[alteration].has("dmg_buff"):
						active_dmg *= user.alterations[alteration].dmg_buff

				var recipient = user if targets_self else target
				messages = _safe_invoke(recipient, "take_damage", [active_dmg])
				ret = [
					(
						"Target "
						+ (messages[0] if messages.size() > 0 else "")
						+ " from "
						+ skill_name
					),
					"Target " + (messages[1] if messages.size() > 1 else "")
				]
			"movement":
				print("Activating movement")
				var basic_directions = ["U", "D", "L", "R"]
				if details in basic_directions:
					ret = [battle.move_player(details, value)]
			"danger_dmg_mult":
				print("Activating danger")
				var duration = 1
				ret = battle.apply_zones("dmg_mult_", value, details, duration, "bad")
			"poison":
				print("Activating poison!")
				var recipient = user if targets_self else target
				messages = _safe_invoke(recipient, "increase_poison", [value])
				ret = ["Targets " + (messages[0] if messages.size() > 0 else "")]
			"stun":
				print("Stunning!")
				var recipient = user if targets_self else target
				messages = _safe_invoke(recipient, "increase_stun", [value])
				ret = ["Targets " + (messages[0] if messages.size() > 0 else "")]
			"safety_dmg_reduc":
				print("Activating safety")
				var duration = 1
				ret = battle.apply_zones("dmg_reduc_", value, details, duration, "good")
			"death_zone":
				print("Activating death")
				var duration = 1
				var direction
				if (targets_self and user.is_player) or (!targets_self and !user.is_player):
					direction = "bad"
				else:
					direction = "good"
				ret = battle.apply_zones("death_", value, details, duration, direction)
			"heal_zone":
				print("Activating death")
				var duration = 1
				var direction
				if (targets_self and user.is_player) or (!targets_self and !user.is_player):
					direction = "good"
				else:
					direction = "bad"
				ret = battle.apply_zones("heal_", value, details, duration, direction)
			"heal":
				var recipient = user if targets_self else target
				ret = _safe_invoke(recipient, "heal", [value])
			"damage_buff":
				var dur = null
				if "duration" in details:
					var parts = details.split("=")
					dur = int(parts[1])
				var recipient = user if targets_self else target
				ret = _safe_invoke(recipient, "add_alteration", ["dmg_buff", value, skill_name, dur])
			"prepare":
				var prep_msg := "The enemy seems to be preparing something big... or maybe it's just tired?"
				var prep_hint := "Hard to tell really"
				ret = [prep_msg, prep_hint]
		if depth<3 and not battle.battle_over():
			battle.update_passives(depth+1)
		return ret

	# gdlint: enable=max-returns
