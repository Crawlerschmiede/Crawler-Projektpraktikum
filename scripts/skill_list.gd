extends Control

signal player_turn_done

enum Tab { SKILLS, ITEMS, ACTIONS }

var tooltip_container: Node

var player: Node
var enemy: Node

var player_turn: bool = true
var battle_scene: CanvasLayer = null
var custom_font = load("res://assets/font/PixelPurl.ttf")

@onready var tab_bar: TabBar = $TabBar
@onready var list_vbox: VBoxContainer = $ScrollContainer/VBoxContainer


func setup(_player: Node, _enemy: Node, _battle_scene, _tooltip_container):
	player = _player
	enemy = _enemy
	battle_scene = _battle_scene
	tooltip_container = _tooltip_container
	tab_bar.tab_changed.connect(_on_tab_changed)

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
			add_buttons(player.abilities)
		Tab.ACTIONS:
			add_buttons(player.actions)
	if list_vbox.get_child_count() > 0:
		list_vbox.get_child(0).grab_focus()
		
func add_buttons(contents):
	for ability in contents:
		var butt_label = ability.name
		if not ability.is_activateable():
			butt_label = butt_label+" (Cooldown: "+str(ability.turns_until_reuse)+")"
			_add_button_disabled(butt_label)
		else:
			_add_button(
				butt_label,
				_on_skill_pressed.bind(ability),
				_on_mouse_entered.bind(ability.name, ability.description),
				)



func _clear_vbox(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.queue_free()
		
func _add_button_disabled(label: String)->void:
	var b := Button.new()
	b.text = label
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())

	b.add_theme_font_override("font", custom_font)
	b.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	list_vbox.add_child(b)
	


func _add_button(label: String, pressed_cb: Callable, mouseover_cb: Callable) -> void:
	var b := Button.new()
	b.text = label

	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())

	b.add_theme_font_override("font", custom_font)
	b.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	# Mouse hover = selected
	b.mouse_entered.connect(mouseover_cb)
	b.mouse_exited.connect(remove_tooltip)

	# Keyboard focus = selected (SAME DESIGN)
	b.focus_entered.connect(mouseover_cb)
	b.focus_exited.connect(remove_tooltip)

	# Auto scroll to focused button
	b.focus_entered.connect(_scroll_to_button.bind(b))

	# Press
	b.pressed.connect(pressed_cb)

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
		$ScrollContainer/VBoxContainer.scroll_vertical -= $ScrollContainer/VBoxContainer.position.y - btn_rect.position.y + 8



func _on_skill_pressed(ability) -> void:
	if player_turn:
		var stuff = ability.activate_skill(player, enemy, battle_scene)
		print("did the function thing!")
		for thing in stuff:
			battle_scene.log_container.add_log_event(thing)
		player_turn = false
		player_turn_done.emit()


func _on_mouse_entered(skill_name, skill_description):
	if tooltip_container != null:
		tooltip_container.state = "tooltip"
		tooltip_container.changed = true
		tooltip_container.tooltips = [skill_name.to_upper(), skill_description]
		print("Test")


func _process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		remove_tooltip()


func remove_tooltip():
	if tooltip_container != null:
		tooltip_container.state = "log"
		tooltip_container.changed = true

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
