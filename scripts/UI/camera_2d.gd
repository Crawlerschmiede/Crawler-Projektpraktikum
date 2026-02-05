extends Camera2D

const SETTINGS_MANAGER_PATH := "/root/SettingsManager"


func _ready() -> void:
	_apply_zoom_from_settings()
	var mgr = _get_manager()
	if mgr != null and mgr.has_signal("game_settings_changed"):
		mgr.game_settings_changed.connect(_on_game_settings_changed)


func _get_manager():
	return get_node(SETTINGS_MANAGER_PATH) if has_node(SETTINGS_MANAGER_PATH) else null


func _on_game_settings_changed() -> void:
	_apply_zoom_from_settings()


func _apply_zoom_from_settings() -> void:
	var mgr = _get_manager()
	if mgr == null:
		return

	var base: float = mgr.get_zoom_base()
	var step: float = mgr.get_zoom_step()
	var steps: int = mgr.get_zoom_steps()
	var level: int = mgr.get_zoom_level()

	steps = max(steps, 0)
	level = clampi(level, -steps, steps)
	var zoom_value: float = base + (float(level) * step)
	zoom_value = maxf(zoom_value, 0.01)
	zoom = Vector2(zoom_value, zoom_value)
