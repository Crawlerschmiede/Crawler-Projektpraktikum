extends Control

const START_SCENE := "res://scenes/UI/start-menu.tscn"

var cursor_idle = preload("res://assets/menu/normal.png")
var cursor_click = preload("res://assets/menu/clicked.png")

var _pressed: bool = false

@onready var bg_music = $bg_music

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = true

	# Cursor setzen
	if cursor_idle != null:
		Input.set_custom_mouse_cursor(cursor_idle)

	# Debug: log whether SceneTree is paused when death scene loads
	var tree = get_tree()
	if tree != null:
		print("death_screen: SceneTree.paused =", tree.paused)
	else:
		var ml = Engine.get_main_loop()
		if ml != null and ml is SceneTree:
			print("death_screen: fallback main_loop SceneTree.paused =", ml.paused)

	# Musik soft starten (wenn vorhanden)
	if bg_music != null:
		bg_music.volume_db = -80.0
		bg_music.play(0.0)
		var fade_tween = create_tween()
		fade_tween.tween_property(bg_music, "volume_db", 0.0, 1.5).set_trans(Tween.TRANS_SINE)

	_wire_buttons()
	_setup_focus_navigation()


func _wire_buttons() -> void:
	# Prefer the explicitly linked button inside the PanelContainer
	var btn: Button = null
	if has_node("PanelContainer/MarginContainer/VBoxContainer/Button"):
		btn = $PanelContainer/MarginContainer/VBoxContainer/Button
	else:
		var btns := find_children("*", "Button", true, false)
		if btns.size() > 0:
			btn = btns[0]

	if btn != null:
		# assign custom button script for nice visuals (if available)
		var cb = load("res://scripts/UI/custom_button.gd")
		if cb != null and btn.get_script() != cb:
			btn.set_script(cb)

		# Ensure button is enabled and accepts mouse
		btn.disabled = false
		btn.visible = true
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_ALL

		if not btn.is_connected("pressed", Callable(self, "_on_continue_pressed")):
			btn.connect("pressed", Callable(self, "_on_continue_pressed"))

		# Ensure focus/clickability and log status
		btn.grab_focus()
		print("death_screen: wired button:", btn.get_path(), "script=", btn.get_script(), "disabled=", btn.disabled, "visible=", btn.visible, "mouse_filter=", btn.mouse_filter)

		# Move this StartMenu to the top of the scene root so it receives input above autoloads
		var parent = get_parent()
		if parent != null:
			var idx = parent.get_child_count() - 1
			parent.move_child(self, idx)
			print("death_screen: moved StartMenu to top, parent child_count=", parent.get_child_count())

		# Remove any CanvasLayer overlays that might still capture input (e.g. battle UI)
		var root = get_tree().root
		for ch in root.get_children():
			if ch == self:
				continue
				# free CanvasLayer overlays (but keep audio players)
				if ch is CanvasLayer:
					print("death_screen: freeing overlay:", ch.name)
					ch.queue_free()

	else:
		print("death_screen: no button found to wire")
		# Debug: print subtree to find out what's present
		_print_subtree(self)
		# Also list all Buttons reachable from root
		var all_buttons := []
		for n in get_tree().get_nodes_in_group(""):
			pass
		var btns := find_children("*", "Button", true, true)
		print("death_screen: find_children returned ", btns.size(), " buttons")
		for b in btns:
			print("  -> ", b.get_path(), " (visible=", b.visible, " disabled=", b.disabled, ")")
	else:
		print("death_screen: no button found to wire")


func _setup_focus_navigation() -> void:
	if not has_node("PanelContainer/MarginContainer/VBoxContainer"):
		return

	var container = $PanelContainer/MarginContainer/VBoxContainer
	for child in container.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_ALL

	# Fokus auf ersten Button
	if container.get_child_count() > 0:
		container.get_child(0).grab_focus()


func _input(event):
	# Allow keyboard/gamepad shortcuts to continue without pressing the button
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER or event.scancode == KEY_ESCAPE:
			_on_continue_pressed()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if cursor_click != null:
				Input.set_custom_mouse_cursor(cursor_click)
		else:
			if cursor_idle != null:
				Input.set_custom_mouse_cursor(cursor_idle)


func _process(_delta):
	# also allow action-based input (gamepad/keyboard mappings)
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
		_on_continue_pressed()


func _on_continue_pressed() -> void:
	print("death_screen: _on_continue_pressed called")
	_pressed = true
	_go_to_start()


func _go_to_start() -> void:
	var tree = get_tree()
	if tree == null:
		var ml = Engine.get_main_loop()
		if ml != null and ml is SceneTree:
			tree = ml

	if tree != null:
		print("death_screen: changing scene to", START_SCENE)
		var err = tree.change_scene_to_file(START_SCENE)
		if err != OK:
			push_error("death_screen: change_scene_to_file returned error: %s" % err)
