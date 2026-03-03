extends RefCounted


func _is_boss_enemy(enemy: Node) -> bool:
	if (
		typeof(AudioManager) != TYPE_NIL
		and AudioManager != null
		and AudioManager.has_method("is_boss_enemy")
	):
		return bool(AudioManager.is_boss_enemy(enemy))
	return false


func emit_world_loaded(idx: int) -> void:
	if (
		typeof(GameEvents) != TYPE_NIL
		and GameEvents != null
		and GameEvents.has_method("emit_world_loaded")
	):
		GameEvents.emit_world_loaded(idx)
		return

	if typeof(AudioManager) != TYPE_NIL and AudioManager != null:
		AudioManager.play_world_music(idx)


func emit_battle_started(enemy: Node) -> void:
	var is_boss_enemy := _is_boss_enemy(enemy)

	if (
		typeof(GameEvents) != TYPE_NIL
		and GameEvents != null
		and GameEvents.has_method("emit_battle_started")
	):
		GameEvents.emit_battle_started(enemy, is_boss_enemy)
		return

	if typeof(AudioManager) != TYPE_NIL and AudioManager != null:
		AudioManager.enter_battle(enemy)


func emit_battle_ended(victory: bool, enemy: Node) -> void:
	var is_boss_enemy := _is_boss_enemy(enemy)

	if (
		typeof(GameEvents) != TYPE_NIL
		and GameEvents != null
		and GameEvents.has_method("emit_battle_ended")
	):
		GameEvents.emit_battle_ended(victory, enemy, is_boss_enemy)
		return

	if typeof(AudioManager) != TYPE_NIL and AudioManager != null:
		AudioManager.exit_battle()


func emit_game_over() -> void:
	if (
		typeof(GameEvents) != TYPE_NIL
		and GameEvents != null
		and GameEvents.has_method("emit_game_over")
	):
		GameEvents.emit_game_over()
		return

	if typeof(AudioManager) != TYPE_NIL and AudioManager != null:
		AudioManager.clear_battle_state()
