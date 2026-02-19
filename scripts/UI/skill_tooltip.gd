extends Control

func _ready():
	hide()

func _process(delta):
	if visible:
		global_position = get_global_mouse_position() #+ Vector2(10, 10)

func SkillTooltip(slot, item):
	%SkillTooltip.popup()
	
func HideSkillTolltip():
	%SkillTooltip.hide()
