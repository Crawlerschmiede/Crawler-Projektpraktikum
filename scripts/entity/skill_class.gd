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
var immediate_effects: Array[Effect] = []
var second_turn_effects: Array[Effect] = []
var pre_prepared_effects = [
	"danger_dmg_mult", "safety_dmg_reduc", "death_zone", "heal_zone", "damage_zone"
]
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
	if len(second_turn_effects) != 0:
		last_user = user
		last_target = target
		last_battle = battle
		battle.next_turn.append(self)
	return things_that_happened


func activate_followup():
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


func activate_immediate(user):
	print("immediate activation")
	if len(immediate_effects) > 0:
		for effect in immediate_effects:
			effect.apply(user, null, null, name)
	return []


func add_effect(
	type: String, value: float, targets_self: bool, details: String, first_turn: bool = true
):
	var eff := Effect.new(type, value, targets_self, details)
	if first_turn:
		effects.append(eff)
	else:
		second_turn_effects.append(eff)


func add_immediate_effect(type: String, value: float, targets_self: bool, details: String):
	var eff := Effect.new(type, value, targets_self, details)
	immediate_effects.append(eff)


func is_activateable(user = null, target = null, battle = null) -> bool:
	var activateable = true
	if not turns_until_reuse == 0:
		activateable = false
	if not battle == null:
		for condition in conditions:
			if not condition_met(condition, user, target, battle):
				activateable = false
	return activateable


func tick_down():
	if turns_until_reuse > 0:
		turns_until_reuse = turns_until_reuse - 1


func condition_met(condition_name, user, _target, battle) -> bool:
	var is_met = true
	if "range" in condition_name and user == null:
		return false
	match condition_name:
		"short_range":
			# TODO: the whole [0,1] thing should come from a variable to become
			# variable.
			is_met = battle.is_player_in_range(user.ranges[0])
		"medium_range":
			is_met = battle.is_player_in_range(user.ranges[1])
		"long_range":
			is_met = battle.is_player_in_range(user.ranges[2])
#--- there's definitely a better way of doing this, sure do hope I find it someday ---
		"outside_short_range":
			is_met = not battle.is_player_in_range(user.ranges[0])
		"outside_medium_range":
			is_met = not battle.is_player_in_range(user.ranges[1])
		"outside_long_range":
			is_met = not battle.is_player_in_range(user.ranges[2])
	if "every_x_turns" in condition_name:
		var splits = condition_name.split("=")
		is_met = battle.turn_counter % int(splits[1]) == 0
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
		#out-of-battle-stuff happens here
		if battle == null:
			match type:
				"range_buff":
					match details:
						"short":
							user.ranges[0] = [0, 0 + value]
						"medium":
							user.ranges[1] = [2, 2 + value]
						"long":
							user.ranges[2] = [4 - value, 4]
					ret = []
			return ret

		var active_placement_effects = battle.tile_modifiers.get(battle.player_gridpos, {})
		print("All mods", battle.tile_modifiers)
		print("Active mods: ", active_placement_effects)
		match type:
			"damage":
				print("Activating damage!")
				var active_dmg = value
				var critted = false
				if "ramp" in details:
					var parts = details.split("||")
					if len(parts)>1:
						var ramp_type = parts[1]
						match ramp_type:
							"consecutive":
								if user.is_player:
									if len(battle.player_action_log)>0:
										for i in range(battle.player_action_log.size() - 1, -1, -1):
											if battle.player_action_log[i]==skill_name:
												active_dmg+=1
											else:
												break
				for modifier_name in active_placement_effects:
					var modifier_value = active_placement_effects[modifier_name]

					match modifier_name:
						"dmg_mult_bad":
							if !user.is_player:
								critted = true
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
					if user.alterations[alteration].has("dmg_null"):
						active_dmg = 0

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
				if recipient == target and active_dmg > 0:
					for alteration in target.alterations:
						if target.alterations[alteration].has("counter"):
							var counter_dmg = target.alterations[alteration].counter
							if critted:
								counter_dmg *= 2
							_safe_invoke(user, "take_damage", [counter_dmg])
			"movement":
				print("Activating movement")
				var basic_directions = ["U", "D", "L", "R"]
				var can_move = true

				if user.is_player:
					if user.frozen > 0:
						can_move = false
				else:
					if target.frozen > 0:
						can_move = false
				if (details in basic_directions or "rnd" in details) and can_move:
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
			"freeze":
				print("Freezing!")
				var recipient = user if targets_self else target
				messages = _safe_invoke(recipient, "increase_freeze", [value])
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
			"damage_zone":
				var duration = 1
				var direction
				var active_dmg = value
				if (targets_self and user.is_player) or (!targets_self and !user.is_player):
					direction = "bad"
				else:
					direction = "good"
				for alteration in user.alterations:
					if user.alterations[alteration].has("dmg_buff"):
						active_dmg *= user.alterations[alteration].dmg_buff
					if user.alterations[alteration].has("dmg_null"):
						active_dmg = 0
				ret = battle.apply_zones("damage_", active_dmg, details, duration, direction)
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
				ret = _safe_invoke(
					recipient, "add_alteration", ["dmg_buff", value, skill_name, dur]
				)
			"dodge_chance":
				var dur = null
				if "duration" in details:
					var parts = details.split("=")
					dur = int(parts[1])
				var recipient = user if targets_self else target
				ret = _safe_invoke(
					recipient, "add_alteration", ["dodge_chance", value, skill_name, dur]
				)
			"counter":
				var dur = null
				if "duration" in details:
					var parts = details.split("=")
					dur = int(parts[1])
				var recipient = user if targets_self else target
				ret = _safe_invoke(recipient, "add_alteration", ["counter", value, skill_name, dur])
			"damage_nullification":
				var dur = null
				if "duration" in details:
					var parts = details.split("=")
					dur = int(parts[1])
				var recipient = user if targets_self else target
				ret = _safe_invoke(
					recipient, "add_alteration", ["dmg_null", value, skill_name, dur]
				)
			"action_bonus":
				var dur = null
				if "duration" in details:
					var parts = details.split("=")
					dur = int(parts[1])
				var recipient = user if targets_self else target
				ret = _safe_invoke(
					recipient, "add_alteration", ["action_bonus", value, skill_name, dur]
				)
			"prepare":
				var prep_msg := "The enemy seems to be preparing something big... or maybe it's just tired?"
				var prep_hint := "Hard to tell really"
				ret = [prep_msg, prep_hint]
		if depth < 3 and not battle.battle_over():
			battle.update_passives(depth + 1, false)
		return ret

	# gdlint: enable=max-returns
