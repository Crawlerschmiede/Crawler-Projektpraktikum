class_name PlayerCharacter
extends MoveableEntity

signal exit_reached
signal player_moved

# Time (in seconds) the character pauses on a tile before taking the next step
const STEP_COOLDOWN: float = 0.01
const PLAYER_ACTIVE_SKILLTREES: Array[String] = ["basic"]
const BINDS_AND_MENUS := preload("res://scenes/UI/binds-and-menus.tscn")

var step_timer: float = 0.01
var base_actions = ["Move Up", "Move Down", "Move Left", "Move Right"]
var actions = []
var minimap
var is_armed = false

var fog_layer: TileMapLayer = null
var dynamic_fog: bool = true
var fog_tile_id: int = 0
var _prev_visible := {}  # Dictionary storing previously visible cells as key -> Vector2i
var _binds_and_menus_instance: Control = null
var _binds_and_menus_layer: CanvasLayer = null

@onready var camera: Camera2D = $Camera2D
@onready var minimap_viewport: SubViewport = $CanvasLayer/SubViewportContainer/SubViewport
@onready var pickup_ui = $CanvasLayer2
@onready var inventory = $UserInterface/Inventory
#@export var binds_and_menus: PackedScene


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _input(_event):
	# Check if the 'toggle_menu' action (H) was just pressed
	if Input.is_action_just_pressed("binds_and_menus"):
		if _binds_and_menus_instance == null:
			_open_menu()
		else:
			_close_menu()


func _open_menu() -> void:
	if _binds_and_menus_instance != null:
		return

	_binds_and_menus_layer = CanvasLayer.new()
	_binds_and_menus_layer.name = "BindsAndMenusOverlay"
	_binds_and_menus_layer.layer = 100

	get_tree().root.add_child(_binds_and_menus_layer)

	_binds_and_menus_instance = BINDS_AND_MENUS.instantiate()
	_binds_and_menus_layer.add_child(_binds_and_menus_instance)

	_binds_and_menus_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	_binds_and_menus_instance.offset_left = 0
	_binds_and_menus_instance.offset_top = 0
	_binds_and_menus_instance.offset_right = 0
	_binds_and_menus_instance.offset_bottom = 0

	if _binds_and_menus_instance.has_signal("closed"):
		_binds_and_menus_instance.closed.connect(_close_menu)


func _close_menu() -> void:
	if _binds_and_menus_layer:
		_binds_and_menus_layer.queue_free()

	_binds_and_menus_layer = null
	_binds_and_menus_instance = null


func _ready() -> void:
	if camera == null:
		#print("Children:", get_children())
		push_error("❌ Camera2D fehlt im Player!")
		return

	PlayerInventory.item_picked_up.connect(_on_item_picked_up)
	inventory.inventory_changed.connect(update_unlocked_skills)

	camera.make_current()
	super_ready("pc", ["pc"])
	self.is_player = true
	for action in base_actions:
		add_action(action)
	for active_tree in PLAYER_ACTIVE_SKILLTREES:
		existing_skilltrees.increase_tree_level(active_tree)
	update_unlocked_skills()
	add_to_group("player")


func set_minimap(mm: TileMapLayer) -> void:
	minimap = mm

	if minimap == null:
		return

	# falls minimap irgendwo anders hängt -> umhängen
	if minimap.get_parent() != null:
		minimap.get_parent().remove_child(minimap)

	minimap_viewport.add_child(minimap)


# --- Input Handling with Cooldown ---


# Use _physics_process for time-based movement, and pass delta
func _physics_process(delta: float):
	# 1. Update the cooldown timer
	step_timer -= delta
	# 2. Get the current direction the player is holding
	var input_direction = get_held_direction()

	# 3. Check conditions for initiating a move
	if input_direction != Vector2i.ZERO:
		# We only start a new move if the character is not already moving AND the cooldown is ready
		if not is_moving and step_timer <= 0.0:
			move_to_tile(input_direction)
			# Reset the cooldown timer immediately after starting the move
			step_timer = STEP_COOLDOWN
			if _check_exit_tile():
				exit_reached.emit()
			player_moved.emit()
			update_visibility()
			if minimap != null:
				minimap.global_position = -1 * global_position


# Function to get the current input direction vector
func get_held_direction() -> Vector2i:
	var direction = Vector2i.ZERO
	if $UserInterface/Inventory/Inner.visible:
		return direction
	if Input.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT
	elif Input.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif Input.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif Input.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN

	update_animation(direction)
	return direction


func update_animation(direction: Vector2i):
	if sprite == null:
		return
	if direction != Vector2i.ZERO:
		var walk_animation_name = ""
		match direction:
			Vector2i.UP:
				walk_animation_name = "walk_up"
			Vector2i.DOWN:
				walk_animation_name = "walk_down"
			Vector2i.RIGHT:
				walk_animation_name = "walk_right"
				sprite.flip_h = false
			Vector2i.LEFT:
				walk_animation_name = "walk_right"
				sprite.flip_h = true
			_:
				walk_animation_name = "walk_down"

		latest_direction = direction

		sprite.play(walk_animation_name)

	else:
		var idle_animation_name = ""
		if Input.is_action_pressed("tea_bag"):
			idle_animation_name = "tea_bag"
		else:
			match latest_direction:
				Vector2i.UP:
					idle_animation_name = "idle_up"
				Vector2i.DOWN:
					idle_animation_name = "idle_down"
				Vector2i.RIGHT:
					idle_animation_name = "idle_right"
					sprite.flip_h = false
				Vector2i.LEFT:
					idle_animation_name = "idle_right"
					sprite.flip_h = true
				_:
					idle_animation_name = "idle_down"

		# Play the determined idle animation
		sprite.play(idle_animation_name)


func _on_item_picked_up(item_name: String, amount: int) -> void:
	pickup_ui.show_pickup(item_name, amount)


func add_action(skill_name):
	var skill = existing_skills.get_skill(skill_name)
	if skill != null:
		actions.append(skill)


func _on_area_2d_area_entered(area: Area2D):
	# Prüfen, ob das Objekt eine Funktion "collect" besitzt
	if area.has_method("collect"):
		area.collect(self)  # dem Item den Player übergen


func level_up():
	self.max_hp = self.max_hp + 1
	self.hp = self.max_hp
	existing_skilltrees.increase_tree_level("Medium Ranged Weaponry")
	update_unlocked_skills()


func _check_exit_tile() -> bool:
	if tilemap == null:
		return false

	var td := tilemap.get_cell_tile_data(grid_pos)
	if td == null:
		return false

	# Custom Data "exit" muss im Tileset gesetzt sein (bool)
	return td.get_custom_data("exit") == true


func is_hiding() -> bool:
	var top_cell_coord = tilemap.map_to_local(grid_pos + Vector2i.DOWN)
	var cell = top_layer.local_to_map(top_cell_coord)
	var tile_data = top_layer.get_cell_tile_data(cell)
	if not tile_data == null and tile_data.get_custom_data("pillar_base") == true:
		return true
	return false


func update_unlocked_skills():
	print("update_skills")
	abilities = []
	var gotten_skills = existing_skilltrees.get_active_skills()
	var equipped_skills = inventory.get_equipment_skills()
	var armed = false
	for extra in equipped_skills:
		gotten_skills.append(extra)
		armed = true
	print("Gotten Skills:", gotten_skills)
	if armed:
		is_armed = true
	else:
		is_armed = false
	for ability in gotten_skills:
		add_skill(ability)


func get_used_range():
	return inventory.get_equipment_range()


func update_visibility():
	if tilemap == null or fog_layer == null:
		print("[DEBUG] update_visibility: tilemap=", tilemap, " fog_layer=", fog_layer)
		return

	var tm := tilemap
	var fog := fog_layer
	var player_cell = tm.local_to_map(global_position)
	var radius := 12  # Sichtweite in Tiles

	var visible_cells := {}

	var erased_count := 0

	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var cell = player_cell + Vector2i(x, y)
			# fast existence check
			if tm.get_cell_source_id(cell) == -1:
				continue
			if not is_path_blocked(player_cell, cell):
				fog.erase_cell(cell)
				erased_count += 1
				visible_cells[_cell_key(cell)] = cell

	print(
		"[DEBUG] update_visibility: erased=", erased_count, "visible_cells=", visible_cells.size()
	)

	if dynamic_fog:
		# Re-fog cells that were visible previously but are not visible now
		for key in _prev_visible.keys():
			if not visible_cells.has(key):
				var c: Vector2i = _prev_visible[key]
				if tm.get_cell_source_id(c) != -1:
					fog.set_cell(c, 2, Vector2(12, 11), 0)

	# store current visible set for next update
	_prev_visible.clear()
	for key in visible_cells.keys():
		_prev_visible[key] = visible_cells[key]


func is_path_blocked(start: Vector2i, end: Vector2i) -> bool:
	var cells = get_line_cells(start, end)

	# nur dazwischen prüfen
	for i in range(1, cells.size() - 1):
		var cell = cells[i]
		var tile_data = tilemap.get_cell_tile_data(cell)

		if tile_data and tile_data.get_custom_data("non_walkable") == true:
			return true

	return false


func get_line_cells(start: Vector2i, end: Vector2i) -> Array:
	var points := []

	var x0 = start.x
	var y0 = start.y
	var x1 = end.x
	var y1 = end.y

	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)

	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1

	var err = dx - dy

	while true:
		points.append(Vector2i(x0, y0))

		if x0 == x1 and y0 == y1:
			break

		var e2 = err * 2

		if e2 > -dy:
			err -= dy
			x0 += sx

		if e2 < dx:
			err += dx
			y0 += sy

	return points


func reveal_on_spawn() -> void:
	# Try to reveal the initial visible area and update minimap position.
	# If tilemap or fog_layer are not yet assigned, try again deferred.
	# If fog_layer wasn't injected (e.g. running the player scene directly),
	# try to find a fog node in the scene tree (look for 'FogWar' or name containing 'fog').
	if fog_layer == null:
		var candidate = get_tree().get_root().find_node("FogWar", true, false)
		if candidate != null and candidate is TileMapLayer:
			fog_layer = candidate
		else:
			var found := _find_fog_node(get_tree().get_root())
			if found != null:
				fog_layer = found

	print("[DEBUG] _reveal_on_spawn: tilemap=", tilemap, " fog_layer=", fog_layer)
	if tilemap == null or fog_layer == null:
		call_deferred("_reveal_on_spawn")
		return

	update_visibility()
	if minimap != null:
		minimap.global_position = -1 * global_position


func _find_fog_node(node: Node) -> TileMapLayer:
	for child in node.get_children():
		if child is TileMapLayer:
			var nm := str(child.name).to_lower()
			if nm.find("fog") != -1:
				return child
		# recursive
		var res := _find_fog_node(child)
		if res != null:
			return res
	# nothing found
	return null
