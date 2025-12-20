extends Resource

class_name Skill

@export var name: String
@export var tree_path: String
@export var description: String
var effects: Array[Effect] = []
var pre_prepared_effects = ["danger_dmg_mult"] #TODO could do with a more sophisticated sorting system later
var high_prio_effects = ["movement"]

func _init(_name: String, _tree_path: String, _description:String):
		name = _name
		tree_path = _tree_path
		description = _description
		
func prep_skill(user, target, battle):
	for effect in effects:
		if effect.type in pre_prepared_effects:
			effect.apply(user, target, battle)

func activate_skill(user, target, battle):
	for effect in effects:
		if effect.type in high_prio_effects && !effect.type in pre_prepared_effects:
			effect.apply(user, target, battle)
	for effect in effects:
		if !effect.type in high_prio_effects && !effect.type in pre_prepared_effects:
			effect.apply(user, target, battle)
	
		
func add_effect(type:String, value:float, targets_self:bool, details:String):
	effects.append(Effect.new(type, value, targets_self, details))
		

class Effect:
	var type: String
	var value: float	
	var targets_self: bool
	var details:String #for general use. i.e., you have a movement type skill, value 1.0, this would hold "left" or "user input" or something,

	func _init(_type: String, _value: float, _targets_self:int, _details:String):
		type = _type
		value = _value
		targets_self = _targets_self
		details = _details
		
	func apply(user, target, battle):
		match type:
			"damage":
				print("Activating damage!")
				var active_dmg = value
				var active_placement_effects = battle.tile_modifiers.get(battle.player_gridpos, {})
				print("All mods", battle.tile_modifiers)
				print("Active mods: ", active_placement_effects)
				for modifier_name in active_placement_effects:
					var modifier_value = active_placement_effects[modifier_name]

					match modifier_name:
						"dmg_mult_bad":
							if !user.is_player:
								active_dmg *= modifier_value
						"dmg_mult_good":
							if user.is_player:
								active_dmg *= modifier_value

				if targets_self:
					user.take_damage(active_dmg)
				else:
					target.take_damage(active_dmg)
			"movement":
				print("Activating movement")
				var basic_directions = ["U", "D", "L", "R"]
				if details in basic_directions:
					battle.move_player(details, value)
			"danger_dmg_mult":
				print("Activating danger")
				var duration=1
				battle.apply_danger_zones(value, details, duration, "bad")
