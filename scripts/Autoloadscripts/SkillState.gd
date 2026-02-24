extends Node

var selected_skills: Array[String] = []

var skill_scene_paths := {
	"Cleric": "res://scenes/UI/Skills/Cleric.tscn",
	"Long-Ranged-Weaponry": "res://scenes/UI/Skills/Long-Ranged-Weaponry.tscn",
	"Mage": "res://scenes/UI/Skills/Mage.tscn",
	"Medium-Ranged-Weaponry": "res://scenes/UI/Skills/Medium-Ranged-Weaponry.tscn",
	"Rogue": "res://scenes/UI/Skills/Rogue.tscn",
	"Short-Ranged-Weaponry": "res://scenes/UI/Skills/Short-Ranged-Weaponry.tscn",
	"Unarmed-Combat": "res://scenes/UI/Skills/Unarmed-Combat.tscn",
	"Warrior": "res://scenes/UI/Skills/Warrior.tscn"
}
