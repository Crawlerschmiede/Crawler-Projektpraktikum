extends Resource

class_name Skill

@export var name: String
@export var tree_path: String
@export var description: String
var effects: Array[Effect] = []

func _init(_name: String, _tree_path: String, _description:String):
		name = _name
		tree_path = _tree_path
		description = _description

func activate_skill(user, target):
	for effect in effects:
		effect.apply(user, target)
		
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
		details = details
		
	func apply(user, target):
		match type:
			"damage":
				if targets_self:
					user.take_damage(value)
				else:
					target.take_damage(value)
			"movement":
				print("Moving", details)
