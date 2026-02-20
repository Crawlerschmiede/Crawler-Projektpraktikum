extends Control

@onready var popup_panel: PopupPanel = %SkillTooltip


func _ready():
	popup_panel.hide()


func _process(_delta):
	if popup_panel.visible:
		popup_panel.position = get_global_mouse_position() + Vector2(5, 5)


func skill_tooltip(_slot, _item):
	popup_panel.popup()
	popup_panel.position = get_global_mouse_position() + Vector2(5, 5)


func hide_skill_tolltip():
	popup_panel.hide()
