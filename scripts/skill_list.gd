extends Control

signal player_turn_done

enum Tab { SKILLS, ITEMS, ACTIONS }

var tooltip_container: Node

var player: Node
var enemy: Node

var player_turn: bool = true
var battle_scene: CanvasLayer = null

@onready var tab_bar: TabBar = $TabBar
@onready var list_vbox: VBoxContainer = $ScrollContainer/VBoxContainer
var custom_font = load("res://assets/font/PixelPurl.ttf")


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


func _on_tab_changed(tab_idx: int) -> void:
	_populate_list(tab_idx)


func _populate_list(tab_idx: int) -> void:
	_clear_vbox(list_vbox)

	match tab_idx:
		Tab.SKILLS:
			for ability in player.abilities:
				_add_button(
					ability.name,
					_on_skill_pressed.bind(ability),
					_on_mouse_entered.bind(ability.name, ability.description),
				)


func _clear_vbox(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.queue_free()


func _add_button(label: String, pressed_cb: Callable, mouseover_cb: Callable) -> void:
	var b := Button.new()

	b.text = label
	# overrides from the basic godot style into custom style
	b.flat = true
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	b.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))  # Light gray

	# 3. Connect Hover signals for the flicker effect
	#b.mouse_entered.connect(_on_button_hover_start.bind(b))
	#b.mouse_exited.connect(_on_button_hover_stop.bind(b))

	b.pressed.connect(pressed_cb)
	b.mouse_entered.connect(mouseover_cb)
	b.add_theme_font_override("font", custom_font)
	list_vbox.add_child(b)


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
