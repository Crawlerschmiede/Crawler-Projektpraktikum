extends Resource

class_name Skill

@export var name: String
@export var tree_path: String
@export var description: String
var effects: Array[Effect] = []

func activate_skill(user, target):
	for effect in effects:
		effect.apply(user, target)
		

# Define the inner class
class Effect:
	var type: String
	var value: float	
	var targets_self: bool
	var details:String #for general use. i.e., you have a movement type skill, value 1.0, this would hold "left" or "user input" or something,

	func _init(_type: String, _value: float, _targets_self:int):
		type = _type
		value = _value
		targets_self = _targets_self
		
	func apply(user, target):
		match type:
			"damage":
				if targets_self:
					user.takeDamage(value)
				else:
					target.takeDamage(value)
