extends Control

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

		print("Current List: ", selected_local, " | Count: ", selected_local.size())


func _on_ConfirmButton_pressed():
	if selected_local.size() == MAX_SELECTIONS:
		SkillState.selected_skills = selected_local.duplicate()
		print("Finalizing Selections: ", SkillState.selected_skills)
		get_tree().change_scene_to_file("res://scenes/UI/skilltree-upgrading.tscn")
	else:
		print("Refusing to confirm. Current count is: ", selected_local.size())
