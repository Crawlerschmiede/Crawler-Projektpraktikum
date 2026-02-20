extends Control

@onready var buttons_container = $Upgrades
@onready var lines_container = $Lines
#@onready var set_shader_hover = preload("res://shaders/lol_button.gdshader")
@onready var tooltip = $SkillTooltip


func _ready():
	await get_tree().process_frame

	var all_skills = buttons_container.get_children()
	for i in range(all_skills.size()):
		var current_skill = all_skills[i] as SkillNode
		if i > 0:
			var previous_skill = all_skills[i - 1] as SkillNode
			current_skill.requirements.append(previous_skill)
			var new_line = create_line(previous_skill, current_skill)
			current_skill.incoming_line = new_line
		current_skill.check_unlockability()

	for skill in all_skills:
		if skill is SkillNode:
			skill.check_unlockability()
			skill.mouse_entered.connect(_on_skill_hover.bind(skill))
			skill.mouse_exited.connect(_on_skill_unhover.bind(skill))

	for skill in buttons_container.get_children():
		if skill is SkillNode:
			var btn = skill.upgrade_button
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))


func create_line(node_a, node_b) -> Line2D:
	var line = Line2D.new()
	lines_container.add_child(line)

	line.width = 3
	line.default_color = Color(0.5, 0.5, 0.5)  # Grey by default

	var pos_a = node_a.global_position + (node_a.size / 2)
	var pos_b = node_b.global_position + (node_b.size / 2)

	line.add_point(pos_a)
	line.add_point(pos_b)

	line.name = "Line_" + node_b.name
	return line


func _on_btn_hover(btn: Button):
	var tween = create_tween()

	tween.tween_method(func(v): btn.material.set_shader_parameter("is_hovered", v), 0.0, 1.0, 0.2)


func _on_btn_unhover(btn: Button):
	var tween = create_tween()
	tween.tween_method(func(v): btn.material.set_shader_parameter("is_hovered", v), 1.0, 0.0, 0.2)


func _on_skill_hover(_skill: SkillNode):
	var mouse_position = get_global_mouse_position()
	tooltip.skill_tooltip(Rect2i(mouse_position, Vector2i.ZERO), null)


func _on_skill_unhover(_skill: SkillNode):
	tooltip.hide_skill_tolltip()
