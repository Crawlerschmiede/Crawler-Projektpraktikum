extends Node

signal world_loaded(world_index: int)
signal battle_started(enemy: Node, is_boss: bool)
signal battle_ended(victory: bool, enemy: Node, is_boss: bool)
signal game_over


func emit_world_loaded(world_index: int) -> void:
	world_loaded.emit(world_index)


func emit_battle_started(enemy: Node, is_boss: bool) -> void:
	battle_started.emit(enemy, is_boss)


func emit_battle_ended(victory: bool, enemy: Node, is_boss: bool) -> void:
	battle_ended.emit(victory, enemy, is_boss)


func emit_game_over() -> void:
	game_over.emit()
