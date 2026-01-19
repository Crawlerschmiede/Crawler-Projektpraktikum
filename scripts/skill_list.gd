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
		Tab.ACTIONS:
			for ability in player.actions:
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

	b.pressed.connect(pressed_cb)

	b.mouse_entered.connect(mouseover_cb)

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
