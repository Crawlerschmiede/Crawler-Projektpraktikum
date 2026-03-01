extends RefCounted

var _loading_screen: CanvasLayer = null


func show_skilltree_select_menu(host: Node, scene: PackedScene) -> void:
	if host == null or scene == null:
		return

	var skilltree_select = scene.instantiate()
	if skilltree_select == null:
		push_warning(
			"Failed to instantiate skilltree select menu; continuing startup without selection"
		)
		return

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "SkilltreeSelectOverlay"
	ui_layer.layer = 100
	host.add_child(ui_layer)
	ui_layer.add_child(skilltree_select)

	if skilltree_select is Control:
		skilltree_select.set_anchors_preset(Control.PRESET_FULL_RECT)
		skilltree_select.offset_left = 0
		skilltree_select.offset_top = 0
		skilltree_select.offset_right = 0
		skilltree_select.offset_bottom = 0

	if skilltree_select.has_signal("selection_confirmed"):
		await skilltree_select.selection_confirmed

	if is_instance_valid(ui_layer):
		ui_layer.queue_free()


func show_skilltree_upgrading_menu(host: Node, scene: PackedScene) -> void:
	if host == null or scene == null:
		return

	var skilltree_upgrading = scene.instantiate()
	if skilltree_upgrading == null:
		push_warning("Failed to instantiate skilltree upgrading menu; continuing startup")
		return

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "SkilltreeUpgradingOverlay"
	ui_layer.layer = 100
	host.add_child(ui_layer)
	ui_layer.add_child(skilltree_upgrading)

	if skilltree_upgrading is Control:
		skilltree_upgrading.set_anchors_preset(Control.PRESET_FULL_RECT)
		skilltree_upgrading.offset_left = 0
		skilltree_upgrading.offset_top = 0
		skilltree_upgrading.offset_right = 0
		skilltree_upgrading.offset_bottom = 0

	if skilltree_upgrading.has_signal("closed"):
		await skilltree_upgrading.closed

	if is_instance_valid(ui_layer):
		ui_layer.queue_free()


func show_loading(host: Node, loading_scene: PackedScene) -> CanvasLayer:
	if host == null or loading_scene == null:
		return null

	_loading_screen = loading_scene.instantiate() as CanvasLayer
	host.add_child(_loading_screen)

	if _loading_screen != null:
		_loading_screen.layer = 100
	else:
		push_error("_show_loading: loading_screen instance is null")
		return null

	_loading_screen.visible = true
	_loading_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	host.move_child(_loading_screen, host.get_child_count() - 1)

	var tree := host.get_tree()
	if tree != null:
		await tree.process_frame
		await tree.process_frame

	return _loading_screen


func hide_loading() -> void:
	if _loading_screen != null and is_instance_valid(_loading_screen):
		_loading_screen.visible = false


func bind_loading_to_generator(generator: Node) -> void:
	if _loading_screen == null or not is_instance_valid(_loading_screen) or generator == null:
		return
	if _loading_screen.has_method("bind_to_generator"):
		_loading_screen.call("bind_to_generator", generator)


func show_start(host: Node, start_scene_path: String, start_new_callback: Callable) -> void:
	if host == null or start_scene_path == "":
		return

	var start_scene = load(start_scene_path)
	if start_scene == null:
		push_warning("show_start: failed to load start scene")
		return

	var start_screen = start_scene.instantiate() as CanvasLayer
	if start_screen == null:
		return

	host.add_child(start_screen)
	start_screen.layer = 1000
	start_screen.visible = true
	start_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	host.move_child(start_screen, host.get_child_count() - 1)

	if start_screen.has_signal("start_new_pressed") and start_new_callback.is_valid():
		start_screen.start_new_pressed.connect(start_new_callback)

	var tree := host.get_tree()
	if tree != null:
		await tree.process_frame
		await tree.process_frame


func get_loading_screen() -> CanvasLayer:
	return _loading_screen
