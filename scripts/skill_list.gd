extends Control

@onready var tab_bar: TabBar = $TabBar
@onready var list_vbox: VBoxContainer = $ScrollContainer/VBoxContainer

signal player_turn_done

var player: Node
var enemy: Node

var player_turn:bool = true
var battle_scene: CanvasLayer = null

enum Tab { SKILLS, ITEMS, ACTIONS }

func setup(_player:Node, _enemy:Node, _battle_scene):
	player = _player
	enemy = _enemy
	battle_scene = _battle_scene
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
				_add_button(ability.name, _on_skill_pressed.bind(ability))
		

func _clear_vbox(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.queue_free()

func _add_button(label: String, pressed_cb: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.pressed.connect(pressed_cb)
	list_vbox.add_child(b)

func _on_skill_pressed(ability) -> void:
	if player_turn:
		var stuff = ability.activate_skill(player, enemy, battle_scene)
		print("did the function thing!")
		for thing in stuff:
			battle_scene.log_container.add_log_event(thing)
		player_turn=false
		player_turn_done.emit()
