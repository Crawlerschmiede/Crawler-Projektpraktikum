extends Control

signal leveled_up

var skills_db = SkillState.skilltrees.existing_skills
var skilltrees = SkillState.skilltrees
var tree_aliases := {"Unarmed Combat": "Unarmed"}
var already_leveled: bool = false

@onready var buttons_container = $Upgrades
@onready var lines_container = $Lines
#@onready var set_shader_hover = preload("res://shaders/lol_button.gdshader")
@onready var tooltip = $SkillTooltip
@onready var card_label: Label = $Card/Label


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
			if skill.has_signal("tree_leveled"):
				skill.tree_leveled.connect(_on_tree_levelup)
			skill.check_unlockability()
			skill.mouse_entered.connect(_on_skill_hover.bind(skill))
			skill.mouse_exited.connect(_on_skill_unhover.bind(skill))

	for skill in buttons_container.get_children():
		if skill is SkillNode:
			var btn = skill.upgrade_button
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))


func _on_tree_levelup(tree_name):
	if not already_leveled:
		skilltrees.increase_tree_level(tree_name)
	leveled_up.emit()


func lock_levelup():
	already_leveled = true


func is_levelup_locked() -> bool:
	return already_leveled


func create_line(node_a, node_b) -> Line2D:
	var line = Line2D.new()
	lines_container.add_child(line)

	line.width = 3
	line.default_color = Color(0.5, 0.5, 0.5)  # Grey by default

	var center_a_global = node_a.global_position + (node_a.size / 2)
	var center_b_global = node_b.global_position + (node_b.size / 2)
	var lines_to_local: Transform2D = lines_container.get_global_transform().affine_inverse()
	var pos_a = lines_to_local * center_a_global
	var pos_b = lines_to_local * center_b_global

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


func _on_skill_hover(skill: SkillNode):
	var skill_name = _get_skill_display_name(skill)
	var skill_description = _get_skill_description(skill_name, skill)
	tooltip.show_tooltip(skill_name, skill_description)


func _on_skill_unhover(_skill: SkillNode):
	tooltip.hide_skill_tolltip()


func _get_skill_display_name(skill: SkillNode) -> String:
	var label_node := skill.get_node_or_null("Label") as Label
	if label_node != null:
		return label_node.text.strip_edges()
	return skill.name


func _get_skill_description(display_name: String, skill: SkillNode) -> String:
	var by_name_key = _find_skill_key_by_name(display_name)
	if by_name_key != "":
		return skills_db.get_detailed_description(by_name_key)

	var by_tier_key = _find_skill_key_by_tree_tier(skill)
	if by_tier_key != "":
		return skills_db.get_detailed_description(by_tier_key)

	return "No description available yet."


func _find_skill_key_by_name(display_name: String) -> String:
	var wanted = _normalize_text(display_name)
	for skill_name in skills_db.existing_skills.keys():
		if _normalize_text(skill_name) == wanted:
			return skill_name
	return ""


func _find_skill_key_by_tree_tier(skill: SkillNode) -> String:
	if not skill.name.begins_with("Skill"):
		return ""

	var tier = int(skill.name.trim_prefix("Skill"))
	if tier < 1:
		return ""

	var tree_name = card_label.text.strip_edges()
	if tree_aliases.has(tree_name):
		tree_name = tree_aliases[tree_name]

	var skills_in_tree = skills_db.get_skills_by_tree(tree_name)
	if skills_in_tree.is_empty():
		return ""

	skills_in_tree.sort_custom(
		func(a, b): return int(a[1].get("tier", 0)) < int(b[1].get("tier", 0))
	)

	if tier - 1 >= 0 and tier - 1 < skills_in_tree.size():
		return str(skills_in_tree[tier - 1][0])

	return ""


func _normalize_text(value: String) -> String:
	var lower = value.to_lower()
	var out = ""
	for i in range(lower.length()):
		var ch = lower[i]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out
