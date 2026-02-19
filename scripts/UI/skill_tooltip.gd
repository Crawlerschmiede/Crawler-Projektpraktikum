extends Control

@onready var popup_panel: PopupPanel = %SkillTooltip


func _ready():
	popup_panel.hide()


func _process(delta):
	if popup_panel.visible:
		popup_panel.position = get_global_mouse_position() + Vector2(5, 5)


func SkillTooltip(slot, item):
	popup_panel.popup()
	popup_panel.position = get_global_mouse_position() + Vector2(5, 5)


func HideSkillTolltip():
	popup_panel.hide()
