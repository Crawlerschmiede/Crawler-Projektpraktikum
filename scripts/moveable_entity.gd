# gdlint: disable=max-public-methods
class_name MoveableEntity
extends CharacterBody2D

# --- Constants ---
# The size of one tile in pixels
const TILE_SIZE: int = 16
const SKILLS := preload("res://scripts/premade_skills.gd")
const DIRECTIONS = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

# --- Member variables ---
var is_player: bool = false
var types = ["passive"]
var existing_skills = SKILLS.new()
var abilities_this_has: Array = []
var multi_turn_action = null

var dimensions: Vector2i = Vector2i(1, 1)
# If I built this at all right, you will never need to touch this.
# It should just work with the resize function.
var my_tiles = [Vector2i(0, 0)]

var sprites = {
	"bat":
	[preload("res://scenes/sprite_scenes/bat_sprite_scene.tscn"), ["Screech", "Swoop", "Rabies"]],
	"skeleton":
	[
		preload("res://scenes/sprite_scenes/skeleton_sprite_scene.tscn"),
		["Eye-Flash-Slash", "Swoop", "Feint"]
	],
	"what":
	[
		preload("res://scenes/sprite_scenes/what_sprite_scene.tscn"),
		["Screech", "Vortex", "Encroaching Void"],
		{"idle": "default", "expand": "expand", "alt_default": "expanded_idle"},
		{"standard": [1, 1], "expanded": [1, 3]}
	],
	"ghost":
	[preload("res://scenes/sprite_scenes/ghost_sprite_scene.tscn"), ["Feint", "Encroaching Void"]],
	"base_zombie":
	[
		preload("res://scenes/sprite_scenes/base_zombie_sprite_scene.tscn"),
		["Screech", "Rabies"],
		{"idle": "default", "teleport_start": "dig_down", "teleport_end": "dig_up"}
	],
	"goblin": [preload("res://scenes/sprite_scenes/goblin_sprite_scene.tscn"), ["Bonk", "War Cry"]],
	"orc": [preload("res://scenes/sprite_scenes/orc_sprite_scene.tscn"), ["Bonk"]],
	"plant":
	[
		preload("res://scenes/sprite_scenes/big_plant_sprite_scene.tscn"),
		["Vine Slash", "Entwine", "Poison Ivy", "Herbicide"],
		{"idle": "default", "teleport_start": "dig_down", "teleport_end": "dig_up"}
	],
	"pc": [preload("res://scenes/sprite_scenes/player_sprite_scene.tscn")]
}

var grid_pos: Vector2i
var tilemap: TileMapLayer = null
var top_layer: TileMapLayer = null
var latest_direction = Vector2i.DOWN
var is_moving: bool = false
var rng := GlobalRNG.get_rng()

#--- combat stats ---
var max_hp: int = 1
var hp: int = 1
var str_stat: int = 1
var def_stat: int = 0
var abilities: Array[Skill] = []
var base_action_points: int = 1
var action_points: int

#--- status effects (not sure if this is the best way... it'll be fine!) ---
#--- update it won't be, this is [not very good] and I'll fix it... someday

var stunned = 0
var stun_recovery = 1

var poisoned = 0
var poison_recovery = 1

#--- buffs/debuffs... status effects someday
#should be in the format "<Source_Name>:{"<type>":<value>}"
# something like that...
var alterations = {}

#--- References to other stuff ---

var animations = null

@onready var collision_area: Area2D = $CollisionArea
@onready var sprite: AnimatedSprite2D


# --- Setup ---
func setup(tmap: TileMapLayer, top_map: TileMapLayer, _hp, _str, _def):
	tilemap = tmap
	top_layer = top_map
	max_hp = _hp
	hp = _hp
	str_stat = _str
	def_stat = _def
	action_points = base_action_points


func super_ready(sprite_type: String, entity_type: Array):
	if tilemap == null:
		push_error("❌ MoveableEntity hat keine TileMap! setup(tilemap) vergessen?")
		return
	types = entity_type
	# Spawn logic for player character
	if "pc" in entity_type:
		# TODO: make pc spawn at the current floor's entryway
		position = tilemap.map_to_local(Vector2i(2, 2))
		grid_pos = Vector2i(2, 2)
		position = tilemap.map_to_local(grid_pos)

	# spawn logic for bosses
	elif "boss" in entity_type:
		var possible_spawns = []

		for cell in tilemap.get_used_cells():
			var tile_data = tilemap.get_cell_tile_data(cell)
			if tile_data:
				var is_boss_tile = tile_data.get_custom_data("boss_spawn")
				if is_boss_tile:
					print("found boss tile! ", cell)
					possible_spawns.append(cell)

		var spawnpoint = possible_spawns[rng.randi_range(0, len(possible_spawns) - 1)]
		position = tilemap.map_to_local(spawnpoint)
		grid_pos = spawnpoint

	# Spawn logic for enemies
	else:
		var possible_spawns = []

		for cell in tilemap.get_used_cells():
			var tile_data = tilemap.get_cell_tile_data(cell)
			if tile_data:
				var is_blocked = tile_data.get_custom_data("non_walkable")
				if not is_blocked:
					if "wallbound" in entity_type:
						if is_next_to_wall(cell):
							possible_spawns.append(cell)
					else:
						possible_spawns.append(cell)
			# TODO: add logic for flying enemies, so they can enter certain tiles
			#if entity_type == "enemy_flying":
			#	add water/lava/floor trap tiles as possible spawns

		# Initialize grid position based on where the entity starts
		var spawnpoint = possible_spawns[rng.randi_range(0, len(possible_spawns) - 1)]
		position = tilemap.map_to_local(spawnpoint)
		grid_pos = spawnpoint
	var sprite_scene = sprites[sprite_type]
	sprite = sprite_scene[0].instantiate()
	add_child(sprite)
	sprite.play("default")
	if not "pc" in entity_type:
		abilities_this_has = sprite_scene[1]
		for ability in abilities_this_has:
			add_skill(ability)
	if len(sprite_scene) > 2:
		animations = sprite_scene[2]


# --- Movement Logic ---
func is_next_to_wall(cell: Vector2i):
	var next_to_wall = false
	for i in range(3):
		for j in range(3):
			var adjacent = Vector2i(cell.x + (i - 1), cell.y + (j - 1))
			var adjacent_tile = tilemap.get_cell_tile_data(adjacent)
			if adjacent_tile:
				var adjacent_blocked = adjacent_tile.get_custom_data("non_walkable")
				if adjacent_blocked:
					next_to_wall = true
	return next_to_wall


func can_burrow_through(target_cell, direction):
	var new_target = target_cell
	for i in range(3):
		new_target = new_target + direction
		if is_cell_walkable(new_target, direction):
			return [true, new_target]
	return [false]


func move_to_tile(direction: Vector2i):
	if is_moving:
		return
	var target_cell = grid_pos + direction
	if not is_cell_walkable(target_cell, direction):
		if "burrowing" in types:
			var burrow = can_burrow_through(target_cell, direction)
			if burrow[0]:
				if has_animation(sprite, "dig_down"):
					sprite.play("dig_down")
				multi_turn_action = {"name": "dig_to", "target": burrow[1], "countdown": 2}
				return
		return

	is_moving = true
	grid_pos = target_cell
	var target_position = tilemap.map_to_local(grid_pos)

	var tween = get_tree().create_tween()
	tween.tween_property(self, "position", target_position, 0.15)
	tween.finished.connect(_on_move_finished)


func teleport_to_tile(coordinates: Vector2i, animation = null) -> void:
	if not is_cell_walkable(coordinates):
		sprite.play("default")
		return
	self.grid_pos = coordinates
	self.position = tilemap.map_to_local(grid_pos)
	if animation != null:
		sprite.play(animation[0])
		await sprite.animation_finished
		sprite.play("default")
	return


func check_collisions() -> void:
	for body in collision_area.get_overlapping_bodies():
		# Nur andere Entities prüfen
		if not body is MoveableEntity:
			continue

		if body == self:
			continue

		if body.is_in_group("item"):
			continue

		for tile in my_tiles:
			for other_tile in body.my_tiles:
				if (grid_pos + tile) == (body.grid_pos + other_tile):
					if self.hp > 0 and body.hp > 0:
						if self.is_player:
							initiate_battle(self, body)
						elif body.is_player:
							initiate_battle(body, self)


func _on_move_finished():
	is_moving = false
	check_collisions()


func is_cell_walkable(cell: Vector2i, direction: Vector2i = Vector2i.ZERO) -> bool:
	# Get the tile data from the TileMapLayer at the given cell
	var tile_data = tilemap.get_cell_tile_data(cell)
	if tile_data == null:
		return false  # No tile = not walkable (outside map)

	# Check for your custom property "non_walkable"
	if tile_data.get_custom_data("non_walkable") == true:
		return false

	if is_cell_blocked(cell, direction):
		return false

	# Prevent stepping onto tiles already occupied by another enemy (no stacking)
	# For multi-tile entities, consider all occupied offsets in `my_tiles`.
	var target_tiles: Array = []
	for t in my_tiles:
		target_tiles.append(cell + t)

	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if e == null:
			continue
		if e == self:
			continue
		if not is_instance_valid(e):
			continue
		# some nodes in the group might not have the expected fields
		if not ("grid_pos" in e and "my_tiles" in e):
			continue
		for other_t in e.my_tiles:
			var other_cell = e.grid_pos + other_t
			for my_t in target_tiles:
				if e.grid_pos == grid_pos:
					return false
				if my_t == other_cell:
					return false
	return true


func is_cell_blocked(cell: Vector2i, direction: Vector2i = Vector2i.ZERO):
	var top_cell_coord = tilemap.map_to_local(cell)
	cell = top_layer.local_to_map(top_cell_coord)
	var tile_data = top_layer.get_cell_tile_data(cell)
	if tile_data == null:
		return false
	if not direction == Vector2i.ZERO:
		var from = cell + (direction * -1)
		var from_data = top_layer.get_cell_tile_data(from)
		if direction == Vector2i.UP:
			if from_data == null:
				return false
			if from_data.get_custom_data("pillar_base") == true:
				return true
		elif direction == Vector2i.DOWN:
			if tile_data.get_custom_data("pillar_base") == true:
				return true


#--skill logic--
func add_skill(skill_name):
	var skill = existing_skills.get_skill(skill_name)
	if skill != null:
		abilities.append(skill)


func activate_passives(user, target, battle):
	for ability in abilities:
		if ability.is_passive:
			ability.activate_skill(user, target, battle)


func add_alteration(type, value, source = "test", duration = null):
	if duration != null:
		alterations[source] = {type: value, "duration": duration}
	else:
		alterations[source] = {type: value}
	return []


func get_alterations():
	return alterations


func deactivate_buff(source = "test"):
	print("alterations ", alterations)
	if alterations.has(source):
		if alterations[source].has("duration") and alterations[source].duration > 0:
			alterations[source].duration = int(alterations[source].duration) - 1
	alterations.erase(source)


#--battle logic--


func initiate_battle(player: Node, enemy: Node) -> bool:
	var main = get_tree().root.get_node("MAIN Pet Dungeon")
	main.instantiate_battle(player, enemy)
	return true


func take_damage(damage):
	#print(self, " takes ", damage, " damage!")
	var taken_damage = damage  #useless right now but just put here for later damage calculations
	hp = hp - taken_damage
	#print("Now has ", hp, "HP")
	return [" took " + str(taken_damage) + " Damage", " now has " + str(hp) + " HP"]


func heal(healing):
	#print(self, " heals by ", healing, "!")
	var healed_hp = healing  #useless right now but just put here for later damage calculations
	hp = hp + healed_hp
	#print("Now has ", hp, "HP")
	return [" healed by " + str(healed_hp), " now has " + str(hp) + " HP"]


func refill_actions():
	action_points = base_action_points
	for alteration in alterations:
		if alterations[alteration].has("action_bonus"):
			action_points += int(alterations[alteration].action_bonus)


#-- status effect logic --


func increase_poison(amount):
	poisoned += amount
	return ["Poison increases to " + str(poisoned) + "!"]


func increase_stun(amount):
	stunned += amount
	return ["Stun increases to " + str(stunned) + "!"]


func full_status_heal():
	stunned = 0
	poisoned = 0


func deal_with_status_effects() -> Array:
	var gets_a_turn = true
	var things_that_happened = []
	if stunned > 0:
		stunned -= stun_recovery
		if stunned < 0:
			stunned = 0
		gets_a_turn = false
		things_that_happened.append("Is stunned and cannot move!")
	if poisoned > 0:
		var message = take_damage(poisoned)
		poisoned -= poison_recovery
		if poisoned < 0:
			poisoned = 0
		things_that_happened.append("Target" + message[0] + " from poison! Target" + message[1])
	return [gets_a_turn, things_that_happened]


# --- helpers ---
func has_animation(checked_sprite: AnimatedSprite2D, anim_name: String) -> bool:
	return checked_sprite.sprite_frames.has_animation(anim_name)


func update_visibility():
	var objects = get_tree().get_nodes_in_group("vision_objects")

	for obj in objects:
		if can_see(obj.global_position):
			obj.visible = true
			print("Updating visibility")
		else:
			obj.visible = false


func can_see(target_pos: Vector2) -> bool:
	if tilemap == null:
		return true

	var start_cell = tilemap.local_to_map(global_position)
	var end_cell = tilemap.local_to_map(target_pos)

	var cells = get_line_cells(start_cell, end_cell)

	# Start- und Ziel-Tile ignorieren!
	for i in range(1, cells.size() - 1):
		var cell = cells[i]

		var tile_data = tilemap.get_cell_tile_data(cell)
		if tile_data:
			if tile_data.get_custom_data("non_walkable") == true:
				return false

	return true


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
