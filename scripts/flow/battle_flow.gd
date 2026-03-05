extends RefCounted

signal player_victory(enemy: Node)
signal player_loss

var _host: Node = null
var _battle_scene: PackedScene = null
var _battle: CanvasLayer = null


func configure(host: Node, battle_scene: PackedScene) -> void:
	_host = host
	_battle_scene = battle_scene


func has_active_battle() -> bool:
	return _battle != null and is_instance_valid(_battle)


func start_battle(player_node: Node, enemy: Node) -> void:
	if has_active_battle():
		return
	if _host == null or _battle_scene == null:
		push_warning("BattleFlow is not configured")
		return

	_battle = _battle_scene.instantiate()
	_battle.player = player_node
	_battle.enemy = enemy
	_battle.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_host.add_child(_battle)

	_connect_battle_signals(enemy)


func clear_battle() -> void:
	if has_active_battle():
		_battle.call_deferred("queue_free")
	_battle = null


func _connect_battle_signals(enemy: Node) -> void:
	if _battle.has_signal("player_victory"):
		var victory_callable_base = Callable(self, "_on_battle_player_victory")
		var victory_callable = victory_callable_base.bind(enemy)
		if not _battle.is_connected("player_victory", victory_callable):
			_battle.connect("player_victory", victory_callable)

	if _battle.has_signal("player_loss"):
		var loss_callable = Callable(self, "_on_battle_player_loss")
		if not _battle.is_connected("player_loss", loss_callable):
			_battle.connect("player_loss", loss_callable)


func _on_battle_player_loss() -> void:
	player_loss.emit()


func _on_battle_player_victory(enemy: Node) -> void:
	player_victory.emit(enemy)
