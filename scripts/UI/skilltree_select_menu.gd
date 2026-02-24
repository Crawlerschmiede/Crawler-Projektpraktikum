extends Control

signal selection_confirmed(selected_skills: Array[String])

const MAX_SELECTIONS := 3

var selected_local: Array[String] = []
var cards_container: Array = []

@onready var confirm_button = $Confirm


func _ready():
	# 1. Find the cards AFTER the scene is ready
	cards_container = _find_skill_cards(self)

	# 2. Clear global state
	SkillState.selected_skills.clear()

	# 3. Connect signals
	for card in cards_container:
		card.gui_input.connect(_on_card_clicked.bind(card))

	_sync_card_visuals()


func _find_skill_cards(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child.has_meta("skill_id"):
			result.append(child)
		result += _find_skill_cards(child)
	return result


func _on_card_clicked(event: InputEvent, card):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var skill_id = card.get_meta("skill_id")

		if skill_id in selected_local:
			# DESELECTTT
			selected_local.erase(skill_id)
			print("Removed: ", skill_id)
		else:
			if selected_local.size() < MAX_SELECTIONS:
				selected_local.append(skill_id)
				print("Added: ", skill_id)
			else:
				print("Cannot add: Max selections (3) reached.")

		_sync_card_visuals()
		print("Current List: ", selected_local, " | Count: ", selected_local.size())


func _sync_card_visuals() -> void:
	for card in cards_container:
		if not card.has_meta("skill_id"):
			continue

		var skill_id = card.get_meta("skill_id")
		var is_selected = skill_id in selected_local
		if card.has_method("set_selected"):
			card.call("set_selected", is_selected)


func _on_ConfirmButton_pressed():
	if selected_local.size() == MAX_SELECTIONS:
		SkillState.selected_skills = selected_local.duplicate()
		print("Finalizing Selections: ", SkillState.selected_skills)
		if get_tree().current_scene == self:
			get_tree().change_scene_to_file("res://scenes/UI/skilltree-upgrading.tscn")
		else:
			emit_signal("selection_confirmed", SkillState.selected_skills)
			queue_free()
	else:
		print("Refusing to confirm. Current count is: ", selected_local.size())
