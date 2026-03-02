extends RefCounted

var _switching_world := false


func is_switching_world() -> bool:
	return _switching_world


func reset_transition_state() -> void:
	_switching_world = false


func try_advance_world(
	current_world_index: int, load_world_callable: Callable, on_tutorial_exit_callable: Callable
) -> int:
	if _switching_world:
		return current_world_index
	if not _can_advance_world():
		return current_world_index
	if not load_world_callable.is_valid():
		push_warning("WorldFlow: load_world_callable is invalid")
		return current_world_index

	_switching_world = true
	if current_world_index == -1 and on_tutorial_exit_callable.is_valid():
		on_tutorial_exit_callable.call()

	var next_world_index := current_world_index + 1
	await load_world_callable.call(next_world_index)
	_switching_world = false
	return next_world_index


func _can_advance_world() -> bool:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return true

	for enemy in scene_tree.get_nodes_in_group("enemy"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not AudioManager.is_boss_enemy(enemy):
			continue
		if int(enemy.get("hp")) > 0:
			push_warning("You must defeat the boss before advancing!")
			return false

	return true
