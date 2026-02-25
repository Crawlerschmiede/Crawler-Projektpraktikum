class_name SkillNode
extends TextureButton

signal tree_leveled(tree_name)

var requirements: Array[SkillNode] = []
var skilltrees = SkillState.skilltrees
var is_unlocked: bool = false
var incoming_line: Line2D = null
var tooltip_script = load("res://scripts/UI/skill_tooltip.gd")
var tooltip = tooltip_script.new()

@onready var glow_shader = preload("res://shaders/glitterglowwithboarder.gdshader")
@onready var upgrade_button: Button = $Unlock

const tree_aliasing={
	"LongRangedWeaponry":"Long-Ranged-Weaponry",
	"UnarmedCombat":"Unarmed-Combat",
	"ShortRangedWeaponry":"Short-Ranged-Weaponry",
	"MediumRangedWeaponry":"Medium-Ranged-Weaponry"
}

func _ready():
	#self.pressed.connect(_on_skill_pressed)
	is_unlocked=already_unlocked()
	update_visuals()
	upgrade_button.visible = false
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	
func already_unlocked():
	var own_tree = tree_aliasing[get_parent().get_parent().name]
	var own_required_tier =  int(str(name)[-1])
	if skilltrees.skilltrees[own_tree]>= own_required_tier:
		return true
	return false
	

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if can_be_unlocked():
			upgrade_button.visible = true
		# Optional: Deselect others if needed
		# get_parent().emit_signal("skill_selected", self)


func _on_upgrade_button_pressed():
	if is_unlocked:
		return

	is_unlocked = true
	update_visuals()
	upgrade_button.visible = false  # Hide after success

	var all_skills = get_tree().get_nodes_in_group("skill_nodes")
	for skill in all_skills:
		if skill is SkillNode:
			skill.check_unlockability()
	tree_leveled.emit(tree_aliasing[get_parent().get_parent().name])


func can_be_unlocked() -> bool:
	if is_unlocked:
		return false
	for req in requirements:
		if not req.is_unlocked:
			return false
	return true


#func _on_skill_pressed():
#if is_unlocked:
#print("Already unlocked!")
#return
#
## Logic: Unlock this skill
#is_unlocked = true
#update_visuals()
#print(name + " unlocked!")
#
#var all_skills = get_tree().get_nodes_in_group("skill_nodes")
#for skill in all_skills:
#if skill is SkillNode:
#skill.check_unlockability()


func check_unlockability():
	if is_unlocked:
		self.material = null
		update_visuals()
		return

	var can_unlock = true
	for req in requirements:
		if not req.is_unlocked:
			can_unlock = false
			break

	if can_unlock:
		self.disabled = false
		self.modulate = Color(1.8, 1.8, 1.2)
		if self.material == null:
			var new_mat = ShaderMaterial.new()
			new_mat.shader = glow_shader
			self.material = new_mat

		self.material.set_shader_parameter("glow_power", 2.0)

		if incoming_line:
			incoming_line.default_color = Color.GOLD
	else:
		self.disabled = true
		self.modulate = Color(0.1, 0.1, 0.1)
		self.material = null
		if incoming_line:
			incoming_line.default_color = Color(0.2, 0.2, 0.2)


func update_visuals():
	if is_unlocked:
		self.disabled = false
		self.modulate = Color.WHITE
		self.material = null
		if incoming_line:
			incoming_line.default_color = Color(1.5, 1.5, 1.2)
