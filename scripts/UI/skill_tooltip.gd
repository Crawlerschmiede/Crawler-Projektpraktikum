extends Control

const TOOLTIP_TEXT_WIDTH: float = 220.0

@onready var popup_panel: PopupPanel = %SkillTooltip
@onready var tooltip_label: Label = $UI/SkillTooltip/VBoxContainer/Label


func _ready():
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.custom_minimum_size.x = TOOLTIP_TEXT_WIDTH
	popup_panel.hide()


func _process(_delta):
	if popup_panel.visible:
		popup_panel.position = get_global_mouse_position() + Vector2(5, 5)


func show_tooltip(skill_name: String, skill_description: String):
	if tooltip_label != null:
		var shown_name = skill_name.strip_edges()
		var shown_description = skill_description.strip_edges()
		if shown_name == "":
			tooltip_label.text = shown_description
		else:
			tooltip_label.text = shown_name + "\n" + shown_description
		tooltip_label.reset_size()
	popup_panel.popup()
	popup_panel.position = get_global_mouse_position() + Vector2(5, 5)
	popup_panel.call_deferred("reset_size")


func hide_skill_tolltip():
	popup_panel.hide()


func skill_tooltip(_slot, _item):
	show_tooltip("", "")
