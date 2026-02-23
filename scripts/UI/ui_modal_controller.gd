class_name UIModalController
extends RefCounted

static var _pause_request_count: int = 0
static var _movement_lock_count: int = 0
static var _tree_was_paused_before_modal: bool = false
static var _debug_enabled: bool = false


static func set_debug_enabled(enabled: bool) -> void:
	_debug_enabled = enabled


static func is_debug_enabled() -> bool:
	return _debug_enabled


static func _context_name(context: Node) -> String:
	if context == null:
		return "<null>"
	return "%s:%s" % [context.name, context.get_script()]


static func _debug_log(context: Node, phase: String, pause_tree: bool, lock_movement: bool) -> void:
	if not _debug_enabled:
		return

	print(
		(
			(
				"[UIModalController] %s | pause=%s lock=%s | "
				+ "pause_count=%d movement_count=%d tree_was_paused=%s caller=%s"
			)
			% [
				phase,
				str(pause_tree),
				str(lock_movement),
				_pause_request_count,
				_movement_lock_count,
				str(_tree_was_paused_before_modal),
				_context_name(context)
			]
		)
	)


static func acquire(context: Node, pause_tree: bool = true, lock_movement: bool = true) -> void:
	if lock_movement:
		_movement_lock_count += 1

	if not pause_tree:
		_debug_log(context, "acquire", pause_tree, lock_movement)
		return

	var scene_tree := context.get_tree() if context != null else null
	if scene_tree == null:
		_debug_log(context, "acquire_no_tree", pause_tree, lock_movement)
		return

	if _pause_request_count == 0:
		_tree_was_paused_before_modal = scene_tree.paused

	_pause_request_count += 1
	if not scene_tree.paused:
		scene_tree.paused = true

	_debug_log(context, "acquire", pause_tree, lock_movement)


static func release(context: Node, pause_tree: bool = true, lock_movement: bool = true) -> void:
	if lock_movement and _movement_lock_count > 0:
		_movement_lock_count -= 1

	if not pause_tree:
		_debug_log(context, "release", pause_tree, lock_movement)
		return

	if _pause_request_count <= 0:
		_debug_log(context, "release_ignored", pause_tree, lock_movement)
		return

	_pause_request_count -= 1
	if _pause_request_count > 0:
		_debug_log(context, "release_deferred", pause_tree, lock_movement)
		return

	var scene_tree := context.get_tree() if context != null else null
	if scene_tree != null and not _tree_was_paused_before_modal:
		scene_tree.paused = false

	_tree_was_paused_before_modal = false
	_debug_log(context, "release", pause_tree, lock_movement)


static func is_movement_locked() -> bool:
	return _movement_lock_count > 0
