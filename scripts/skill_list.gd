extends Control

signal player_turn_done

enum Tab { SKILLS, ITEMS, ACTIONS }

var tooltip_container: Node

var player: Node
var enemy: Node

var player_turn: bool = true
var battle_scene: CanvasLayer = null
var custom_font = load("res://assets/font/PixelPurl.ttf")
var selected_index := 0
var hit_anim_player: AnimatedSprite2D

@onready var tab_bar: TabBar = $TabBar
@onready var list_vbox: VBoxContainer = $ScrollContainer/VBoxContainer


func setup(_player: Node, _enemy: Node, _battle_scene, _tooltip_container, anim_player):
	player = _player
	enemy = _enemy
	battle_scene = _battle_scene
	tooltip_container = _tooltip_container
	hit_anim_player = anim_player
	tab_bar.tab_changed.connect(_on_tab_changed)
	# Ensure this Control receives input events (including when focus is elsewhere)
	set_process_input(true)
	set_process_unhandled_input(true)

	# Try to grab focus so this Control sees key events reliably
	grab_focus()

	# Make sure your tabs exist in this order
	# 0 Skills, 1 Items, 2 Actions
	tab_bar.current_tab = Tab.SKILLS
	_populate_list(Tab.SKILLS)


func update():
	for ability in player.abilities:
		ability.tick_down()
	for action in player.actions:
		action.tick_down()
	_populate_list(tab_bar.current_tab)


func _on_tab_changed(tab_idx: int) -> void:
	_populate_list(tab_idx)


func _populate_list(tab_idx: int) -> void:
	_clear_vbox(list_vbox)
	match tab_idx:
		Tab.SKILLS:
			for ability in player.abilities:
				if not ability.is_passive:
					if ability.is_activateable(battle_scene):
						_add_button(ability)
					else:
						var butt_label = ability.name
						butt_label = (
							butt_label + " (Cooldown: " + str(ability.turns_until_reuse) + ")"
						)
						_add_button_disabled(butt_label)
		Tab.ACTIONS:
			for ability in player.actions:
				_add_button(ability)
	if list_vbox.get_child_count() > 0:
		# wait one frame to ensure buttons are in scene tree
		await get_tree().process_frame
	if list_vbox.get_child_count() > 0:
		selected_index = 0
		_highlight_selected()


func _highlight_selected():
	for i in range(list_vbox.get_child_count()):
		var btn = list_vbox.get_child(i)
		if i == selected_index:
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	# Auto scroll
	var current = list_vbox.get_child(selected_index)
	$ScrollContainer.ensure_control_visible(current)


func _clear_vbox(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.queue_free()


func _add_button_disabled(label: String) -> void:
	var b := Button.new()
	b.text = label
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())

	b.add_theme_font_override("font", custom_font)
	b.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	list_vbox.add_child(b)
	# Make mouse hover update selection (we don't want Tab to change focus)
	b.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind(b))


func _add_button(ability) -> void:
	var b := Button.new()
	b.text = ability.name

	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())

	b.add_theme_font_override("font", custom_font)
	b.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	# Mouse hover = selected -> pass name + description as binds (use Callable.bind)
	b.mouse_entered.connect(
		Callable(self, "_on_mouse_entered").bind(ability.name, ability.description)
	)
	b.mouse_exited.connect(Callable(self, "remove_tooltip"))

	# Keyboard focus = selected (SAME DESIGN)
	# We don't rely on Control focus (Tab should not change selection).
	# Use mouse hover to update selection + tooltip instead.
	b.mouse_entered.connect(
		Callable(self, "_on_mouse_entered").bind(ability.name, ability.description)
	)
	b.mouse_exited.connect(Callable(self, "remove_tooltip"))

	# Mouse hover also sets the internal selection index and scrolls
	b.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind(b))

	# Press (pass ability as bind)
	b.pressed.connect(Callable(self, "_on_skill_pressed").bind(ability))

	list_vbox.add_child(b)


func _scroll_to_button(btn: Button) -> void:
	# Button might already be freed when switching tabs
	if not is_instance_valid(btn):
		return

	await get_tree().process_frame

	if not is_instance_valid(btn):
		return

	var btn_rect = btn.get_global_rect()
	var btn_list = $ScrollContainer/VBoxContainer.get_global_rect()

	if btn_rect.position.y < $ScrollContainer/VBoxContainer.position.y:
		$ScrollContainer/VBoxContainer.scroll_vertical -= (
			$ScrollContainer/VBoxContainer.position.y - btn_rect.position.y + 8
		)


func _on_button_mouse_entered(btn: Button) -> void:
	# Update selected_index to the hovered button and highlight/scroll
	for i in range(list_vbox.get_child_count()):
		if list_vbox.get_child(i) == btn:
			selected_index = i
			_highlight_selected()
			return


func _on_skill_pressed(ability) -> void:
	if player_turn:
		#if hit_anim_player !=null:
		#	hit_anim_player.visible=true
		#	hit_anim_player.play("default")
		#	await hit_anim_player.animation_finished
		#	hit_anim_player.visible=false
		var stuff = ability.activate_skill(player, enemy, battle_scene)
		for thing in stuff:
			battle_scene.log_container.add_log_event(thing)
		player_turn = false
		player_turn_done.emit()


func _on_mouse_entered(skill_name, skill_description):
	if tooltip_container != null:
		tooltip_container.state = "tooltip"
		tooltip_container.changed = true
		tooltip_container.tooltips = [skill_name.to_upper(), skill_description]


func _process(_delta):
	if Input.is_action_just_pressed("ui_down"):
		selected_index += 1
		if selected_index >= list_vbox.get_child_count():
			selected_index = list_vbox.get_child_count() - 1
		_highlight_selected()

	if Input.is_action_just_pressed("ui_up"):
		selected_index -= 1
		if selected_index < 0:
			selected_index = 0
		_highlight_selected()

	if Input.is_action_just_pressed("ui_accept"):
		var btn = list_vbox.get_child(selected_index)
		btn.emit_signal("pressed")

	if Input.is_action_just_pressed("ui_left"):
		_select_prev_tab()

	if Input.is_action_just_pressed("ui_right"):
		_select_next_tab()


func remove_tooltip():
	if tooltip_container != null:
		tooltip_container.state = "log"
		tooltip_container.changed = true


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# TAB komplett blockieren (sicher prüfen, je nach Godot-Version unterschiedliche APIs)
		var is_tab := false
		if event.has_method("get_scancode"):
			if event.get_scancode() == KEY_TAB:
				is_tab = true
		elif event.has_method("get_keycode"):
			if event.get_keycode() == KEY_TAB:
				is_tab = true
		else:
			# Fallback: Textuelle Prüfung (robust, falls Property-API anders ist)
			var txt := ""
			if event.has_method("as_text"):
				txt = event.as_text()
			else:
				txt = str(event)
			if txt.to_lower().find("tab") != -1:
				is_tab = true
		if is_tab:
			accept_event()
			return
		# Navigation is handled in _process() to avoid double-handling
		# (prevent skipping/fast increments when multiple input callbacks fire).


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# TAB blockieren
		var is_tab := false
		if event.has_method("get_scancode") and event.get_scancode() == KEY_TAB:
			is_tab = true
		elif event.has_method("get_keycode") and event.get_keycode() == KEY_TAB:
			is_tab = true
		else:
			var txt := ""
			if event.has_method("as_text"):
				txt = event.as_text()
			else:
				txt = str(event)
			if txt.to_lower().find("tab") != -1:
				is_tab = true
		if is_tab:
			accept_event()
			return

		# Navigation is handled in _process() to avoid double-processing
		# of the same key event (prevents skipping the first entry).


func _select_next_tab() -> void:
	var next_idx := (tab_bar.current_tab + 1) % tab_bar.get_tab_count()
	tab_bar.current_tab = next_idx
	_populate_list(next_idx)


func _select_prev_tab() -> void:
	var count := tab_bar.get_tab_count()
	var prev_idx := (tab_bar.current_tab - 1) % count
	if prev_idx < 0:
		prev_idx += count
	tab_bar.current_tab = prev_idx
	_populate_list(prev_idx)


func _move_focus_delta() -> void:
	# Move focus among the buttons in list_vbox by delta (+1 down, -1 up)
	# Deprecated: we no longer rely on Control focus traversal.
	# Selection is handled via `selected_index` and `_highlight_selected()`.
	return

#var hover_tweens: Dictionary = {}

#func _on_button_hover_start(btn: Button):
# Kill any existing tween for this specific button
#if hover_tweens.has(btn):
#hover_tweens[btn].kill()
#
#var tween = create_tween().set_loops()
#hover_tweens[btn] = tween
#
## Create a "Flicker" by jumping between white and Doom Red/Orange
## The duration (0.05s) makes it feel like a glitchy CRT text
#tween.tween_method(func(val):
#btn.add_theme_color_override("font_color", val),
#Color(1, 1, 1, 1), # Start color (White)
#Color(1, 0.2, 0.2, 0.7), # End color (Soft Red/Glitch)
#0.1
#).set_trans(Tween.TRANS_ELASTIC)
#
#tween.tween_interval(0.05) # Tiny pause to make it "stutter"
#
#func _on_button_hover_stop(btn: Button):
#if hover_tweens.has(btn):
#hover_tweens[btn].kill()
#hover_tweens.erase(btn)
#
## Reset text to normal color
#btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
