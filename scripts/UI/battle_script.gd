extends CanvasLayer

signal player_loss
signal player_victory
signal player_vicory_boss

const MARKER_PREFAB := preload("res://scenes/rooms/helpers/marker.tscn")
const MARKER_FLAVOURS = {
	"dmg_reduc_":
	{
		"visual": "safety",
		"info": "Standing here will let you avoid <PUTVALUEHERE>% of incoming Damage!",
		"log": ["Seems like there's some safe zones here"]
	},
	"dmg_mult_":
	{
		"visual": "danger",
		"info": "Standing here will make you take <PUTVALUEHERE>x Damage!",
		"log":
		[
			"Seems like this attack is more dangerous in some places",
			"Pay attention to your positioning!"
		]
	},
	"damage_":
	{
		"visual": "danger",
		"info": "Standing here will make you take <PUTVALUEHERE> Damage!",
		"log": ["That's a very precise strike!", "As in, there's a lot of places it isn't!"]
	},
	"death_":
	{
		"visual": "death",
		"info": "Look man, it's a floating skull, this is not where want to be standing",
		"log": ["Is that a floating skull?", "Maybe avoid standing there!"]
	},
	"heal_":
	{
		"visual": "heal",
		"info": "Standing here will heal you for <PUTVALUEHERE>!",
		"log": ["Seems like you can grab some healing here"]
	},
	"good_range": {"visual": "good_range", "info": "This is the preferred range for you", "log": []}
}
@export var player: Node
@export var enemy: Node

var active_markers: Array = []
var player_gridpos: Vector2i
var tile_modifiers: Dictionary = {}

var enemy_sprite
var player_sprite
var rng = GlobalRNG.get_rng()

var next_turn: Array[Skill] = []
var turn_counter = 0
var active: bool = true

var over = false

var enemy_action_log = []
var player_action_log = []

var enemy_effect_log = []
var player_effect_log = []

var enemy_is_boss = false
@onready var hit_anim_enemy: AnimatedSprite2D = $Battle_root/PlayerPosition/enemy_attack_anim
@onready var hit_anim_player: AnimatedSprite2D = $Battle_root/EnemyPosition/player_attack_anim
@onready var enemy_marker = $Battle_root/EnemyPosition
@onready var player_marker = $Battle_root/PlayerPosition
@onready var combat_tilemap = $Battle_root/TileMapLayer
@onready var used_cells: Array[Vector2i] = combat_tilemap.get_used_cells()
@onready var skill_ui = $Battle_root/ItemList
@onready var enemy_hp_bar = $Battle_root/Enemy_HPBar
@onready var player_hp_bar = $Battle_root/Player_HPBar
@onready var log_container = $Battle_root/TextureRect2/message_container


func _ready():
	if player != null and is_instance_valid(player):
		player.full_status_heal()
	if enemy != null and is_instance_valid(enemy):
		enemy.full_status_heal()
		enemy_is_boss = AudioManager.is_boss_enemy(enemy)
	enemy_sprite = _create_battle_sprite(enemy)
	player_sprite = _create_battle_sprite(player)
	player_sprite.animation = "idle_up"
	enemy_marker.add_child(enemy_sprite)
	player_gridpos = combat_tilemap.local_to_map(player_marker.position)
	combat_tilemap.add_child(player_sprite)
	player_sprite.position = combat_tilemap.map_to_local(player_gridpos)
	skill_ui.setup(player, enemy, self, log_container, hit_anim_player)
	hit_anim_enemy.visible = false
	hit_anim_player.visible = false
	# confirm setup returned
	# skill_ui.setup already called above; if skill_list prints don't appear, check these messages
	if skill_ui.has_signal("player_turn_done"):
		# Ensure the connection is safe and only happens once
		skill_ui.player_turn_done.connect(enemy_turn)
	if enemy != null and is_instance_valid(enemy):
		enemy_hp_bar.value = (enemy.hp * 100.0) / enemy.max_hp
	if player != null and is_instance_valid(player):
		player_hp_bar.value = (player.hp * 100.0) / player.max_hp
	player.reset_skills()
	print("At the start, player has these: ", player.alterations)
	_add_range_indicators()
	enemy.decide_attack()
	_enemy_prepare_turn()


func dissuade_enemy():
	enemy.decide_attack()
	_enemy_prepare_turn(true)


func _create_battle_sprite(from_actor: CharacterBody2D) -> AnimatedSprite2D:
	var source_sprite := from_actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert(source_sprite)

	var battle_sprite := AnimatedSprite2D.new()

	# Copy visuals
	battle_sprite.sprite_frames = source_sprite.sprite_frames
	battle_sprite.animation = source_sprite.animation
	battle_sprite.frame = source_sprite.frame
	battle_sprite.flip_h = source_sprite.flip_h
	battle_sprite.flip_v = source_sprite.flip_v
	battle_sprite.scale = source_sprite.scale

	battle_sprite.play()

	return battle_sprite


func _enemy_prepare_turn(mid_turn = false):
	# TODO: very low tech; clears everything (ok for 1-turn effects).
	# Anything longer-term will need something more robust.
	print("Tile modifiers right now are: ", tile_modifiers)
	for tile_modifier in tile_modifiers.keys():
		tile_modifiers[tile_modifier]["duration"] -= 1
		if tile_modifiers[tile_modifier]["duration"] <= 0:
			tile_modifiers.erase(tile_modifier)
	_update_marker_visuals()
	log_container.add_log_event("The enemy prepares its Skill " + enemy.chosen.name + "!")
	#print(enemy, " prepares its Skill ", enemy.chosen.name, "!")
	var preps = enemy.chosen.prep_skill(enemy, player, self)
	if not mid_turn:
		_update_passives(true)
		player.refill_actions()
		enemy.refill_actions()
		_update_passives()
	for prep in preps:
		log_container.add_log_event(prep)


func enemy_turn():
	if not active:
		return
	turn_counter += 1
	print("It is turn " + str(turn_counter))
	over = check_victory()
	update_health_bars()
	var happened = []
	if !over:
		for ability in enemy.abilities:
			ability.tick_down()
		var extra_stuff = enemy.deal_with_status_effects(self, 1)
		happened = extra_stuff[1]
		for happening in happened:
			log_container.add_log_event(happening)
		update_health_bars()
		if extra_stuff[0]:
			#print(enemy, " activates its Skill ", enemy.chosen.name, "!")
			happened = await enemy.chosen.activate_skill(enemy, player, self)
			enemy_action_log.append(enemy.chosen.name)
			print(enemy_action_log)
			if hit_anim_enemy != null:
				hit_anim_enemy.visible = true
				hit_anim_enemy.play("triple_strike")
				await hit_anim_enemy.animation_finished
				hit_anim_enemy.visible = false
			for happening in happened:
				log_container.add_log_event(happening)
			enemy.decide_attack()
			_enemy_prepare_turn()
			extra_stuff = enemy.deal_with_status_effects(self, 2)
			happened = extra_stuff[1]
			for happening in happened:
				log_container.add_log_event(happening)
		extra_stuff = player.deal_with_status_effects(self, 1)
		happened = extra_stuff[1]
		update_health_bars()
		for happening in happened:
			log_container.add_log_event(happening)
		if not len(next_turn) == 0:
			for ability in next_turn:
				await ability.activate_followup()
		next_turn = []
		if extra_stuff[0]:
			_player_turn()
			print(player_action_log)
		else:
			enemy_turn()
		over = check_victory()
		update_health_bars()


func update_health_bars():
	if player != null and is_instance_valid(player):
		player_hp_bar.value = (player.hp * 100.0) / player.max_hp
	if enemy != null and is_instance_valid(enemy):
		enemy_hp_bar.value = (enemy.hp * 100.0) / enemy.max_hp


func _player_turn():
	if not active:
		return
	skill_ui.update()
	skill_ui.player_turn = true


func _force_stop() -> void:
	# Immediately stop any further processing inside this battle
	active = false
	# try to disable UI updates
	if skill_ui != null and is_instance_valid(skill_ui):
		skill_ui.player_turn = false
	# hide animations
	if hit_anim_enemy != null:
		hit_anim_enemy.visible = false
	if hit_anim_player != null:
		hit_anim_player.visible = false


func _update_passives(prep = false):
	_trigger_passives(player.abilities, player, enemy, self, prep)
	_trigger_passives(enemy.abilities, enemy, player, self, prep)


func _trigger_passives(abilities, user, target, battle, prep):
	for ability in abilities:
		if ability.is_passive:
			if ability.is_activateable(user, target, self):
				print("Activated the passive effect ", ability.name)
				print_stack()
				if prep:
					await ability.prep_skill(user, target, battle)
				else:
					await ability.activate_skill(user, target, battle)
			else:
				ability.deactivate(user)


func check_victory():
	if over:
		return true
	# Treat missing or freed enemy/player as defeat for that side
	if enemy == null or not is_instance_valid(enemy) or enemy.hp <= 0:
		print("battle_script: emitting player_victory (enemy dead)")
		player_victory.emit()
		return true
	if player == null or not is_instance_valid(player) or player.hp <= 0:
		print("battle_script: emitting player_loss (player dead)")
		player_loss.emit()
		return true
	return false


func _battle_over():
	if enemy == null or not is_instance_valid(enemy) or enemy.hp <= 0:
		return true
	if player == null or not is_instance_valid(player) or player.hp <= 0:
		return true
	return false


func _cell_exists(cell: Vector2i) -> bool:
	# Get the tile data from the TileMapLayer at the given cell
	var tile_data = combat_tilemap.get_cell_tile_data(cell)
	if tile_data == null:
		return false  # No tile = not walkable (outside map)
	return true


func move_player(direction: String, distance: int):
	var dir = ""
	var basics = ["u", "d", "l", "r"]
	var new_cell := player_gridpos
	print("Moving the player in direction: ", direction)
	if player_sprite == null:
		return "One cannot move what doesn't exist. Remember this."
	if direction in basics:
		var delta := Vector2i.ZERO
		match direction:
			"l":
				delta = Vector2i(-distance, 0)
				dir = "left"
			"r":
				delta = Vector2i(distance, 0)
				dir = "right"
			"u":
				delta = Vector2i(0, -distance)
				dir = "up"
			"d":
				delta = Vector2i(0, distance)
				dir = "down"
			_:
				delta = Vector2i.ZERO

		new_cell = player_gridpos + delta
	elif "rnd" in direction:
		var ranges = ["short", "medium", "long"]
		var move_markers = ["dmg_reduc_good"]
		var parts = direction.split("|")
		var area = parts[1]
		var from_to = []
		var min_y = _get_min_y()
		var possible_tiles = []
		match area:
			"short":
				from_to = player.ranges[0]
			"medium":
				from_to = player.ranges[1]
			"long":
				from_to = player.ranges[2]
		if area in ranges:
			for tile in used_cells:
				if tile.y >= (min_y + from_to[0]) and tile.y <= (min_y + from_to[1]):
					possible_tiles.append(tile)
			new_cell = possible_tiles[rng.randi_range(0, len(possible_tiles) - 1)]
		elif area == "dir":
			var new_dir = basics[rng.randi_range(0, len(basics) - 1)]
			return await move_player(new_dir, distance)
		elif area in move_markers:
			for tile in used_cells:
				var modifier_on_tile = tile_modifiers.get(tile, null)
				if modifier_on_tile != null:
					var has_modifier = area in modifier_on_tile.keys()
					if has_modifier:
						possible_tiles.append(tile)
			if possible_tiles.size() > 0:
				new_cell = possible_tiles[rng.randi_range(0, len(possible_tiles) - 1)]
			else:
				return ["But there was no cover..."]
	elif "input" in direction:
		if log_container != null:
			log_container.tooltips = ["Info", "Press an arrow to move"]
			log_container.state = "tooltip"
			log_container.changed = true
		var new_dir := "no"
		while new_dir == "no":
			print("still waiting...")
			await get_tree().process_frame
			new_dir = _get_held_direction()
		if log_container != null:
			log_container.state = "log"
			log_container.changed = true
		return await move_player(new_dir, distance)

	if !_cell_exists(new_cell):
		return "Attempting to move " + dir + ", the player only pushed against the wall"
	player_gridpos = new_cell
	player_sprite.position = combat_tilemap.map_to_local(player_gridpos)
	_check_curr_tile_mods()
	return "Player moved " + dir


func _get_held_direction() -> String:
	var direction = "no"
	if Input.is_action_pressed("move_right"):
		direction = "r"
	elif Input.is_action_pressed("move_left"):
		direction = "l"
	elif Input.is_action_pressed("move_up"):
		direction = "u"
	elif Input.is_action_pressed("move_down"):
		direction = "d"
	return direction


func is_player_in_range(y_from_to) -> bool:
	var min_y = _get_min_y()
	return player_gridpos.y >= min_y + y_from_to[0] and player_gridpos.y <= min_y + y_from_to[1]


func _add_range_indicators():
	var range = _resolve_player_range_bounds(player.get_used_range())
	var valid_ys = []
	print("Valid Range is: ", range)
	if range[0] == range[1]:
		valid_ys.append(int(range[0]))
	else:
		valid_ys.append(int(range[0]))
		valid_ys.append(int(range[1]))

	var valid_cells = []
	for tile in used_cells:
		var min_y = _get_min_y()
		print("Is cell ", tile, " valid in ranges ", range, "?")
		if tile.y - min_y in valid_ys:
			valid_cells.append(tile)
	print("The valid cells are ", valid_cells)
	for cell in valid_cells:
		var marker_info = MARKER_FLAVOURS["good_range"]
		var marker = MARKER_PREFAB.instantiate()

		var marker_visual = marker_info.get("visual", "eugh")
		print("visual is ", marker_visual)
		marker.marker_type = marker_visual
		print("Visual is ", marker_visual)
		print("Adding ", marker.marker_type, " marker!")
		marker.tooltip_container = log_container

		$Battle_root.add_child(marker)
		var world_pos: Vector2 = combat_tilemap.map_to_local(cell)
		marker.global_position = combat_tilemap.to_global(world_pos)


func _resolve_player_range_bounds(used_range) -> Array:
	if used_range is Array and used_range.size() >= 2:
		return [int(used_range[0]), int(used_range[1])]

	match str(used_range):
		"short":
			return [int(player.ranges[0][0]), int(player.ranges[0][1])]
		"medium":
			return [int(player.ranges[1][0]), int(player.ranges[1][1])]
		"long":
			return [int(player.ranges[2][0]), int(player.ranges[2][1])]
		_:
			# Unknown range names fall back to short to avoid runtime errors.
			return [int(player.ranges[0][0]), int(player.ranges[0][1])]


func get_player_range_dmg_mult():
	var dmg_mult: float = 1.0
	var calculated_range = player.get_used_range()
	var base_tiles = [0, 0]
	var player_y = player_gridpos.y - _get_min_y()
	match calculated_range:
		"short":
			base_tiles = player.ranges[0]
		"medium":
			base_tiles = player.ranges[1]
		"long":
			base_tiles = player.ranges[2]
	var dist = 0
	if player_y < base_tiles[0]:
		dist = base_tiles[0] - player_y
	elif player_y > base_tiles[1]:
		dist = player_y - base_tiles[1]
	dmg_mult = 1.0 - (dist * 0.3)
	if dmg_mult < 0:
		dmg_mult = 0
	return dmg_mult


func get_player_pos_modifiers():
	return tile_modifiers.get(player_gridpos, {})


func _check_curr_tile_mods():
	var active_placement_effects = get_player_pos_modifiers()
	for modifier_name in active_placement_effects:
		var modifier_value = active_placement_effects[modifier_name]

		match modifier_name:
			"death_bad":
				player.hp = 0
			"death_good":
				enemy.hp = 0
			"damage_bad":
				player.take_damage(modifier_value)
			"damage_good":
				enemy.take_damage(modifier_value)
			"heal_good":
				player.heal(modifier_value)
			"heal_bad":
				enemy.heal(modifier_value)
	over = check_victory()


func _get_min_x():
	var min_x = 99999999999999
	for tile in used_cells:
		if tile.x < min_x:
			min_x = tile.x
	return min_x


func _get_min_y():
	var min_y = 99999999999999
	for tile in used_cells:
		if tile.y < min_y:
			min_y = tile.y
	return min_y


func apply_zones(zone_type, mult, pos, dur, direction):
	print("Applying ", zone_type, " zones at ", pos)
	# NOTE: duration currently unused (effects are 1-turn only).
	var mult_type = zone_type + direction
	var marker_info = MARKER_FLAVOURS[zone_type]
	var marker_visual = marker_info["visual"]
	if pos == "player_x":
		for tile in used_cells:
			if tile.x == player_gridpos.x:
				tile_modifiers[tile] = {
					mult_type: mult, "duration": dur, "type": zone_type, "mult": mult
				}
	elif pos == "player_y":
		for tile in used_cells:
			if tile.y == player_gridpos.y:
				tile_modifiers[tile] = {
					mult_type: mult, "duration": dur, "type": zone_type, "mult": mult
				}
	elif pos == "player_pos":
		for tile in used_cells:
			if tile == player_gridpos:
				tile_modifiers[tile] = {
					mult_type: mult, "duration": dur, "type": zone_type, "mult": mult
				}
	elif pos == "surrounding":
		for tile in used_cells:
			if tile == player_gridpos:
				continue
			elif (
				(
					tile.x == player_gridpos.x - 1
					or tile.x == player_gridpos.x
					or tile.x == player_gridpos.x + 1
				)
				and (
					tile.y == player_gridpos.y - 1
					or tile.y == player_gridpos.y
					or tile.y == player_gridpos.y + 1
				)
			):
				tile_modifiers[tile] = {
					mult_type: mult, "duration": dur, "type": zone_type, "mult": mult
				}
	elif "area" in pos:  #expecting a string like "area||<x>||<y>||<size>"
		var min_x = _get_min_x()
		var min_y = _get_min_y()
		var splits = pos.split("||")
		var targ_x = splits[1]
		var targ_y = splits[2]
		var area = int(splits[3])

		if targ_x == "rand":
			targ_x = rng.randi_range(0, 4)
		elif targ_x == "p":
			targ_x = player_gridpos.x

		if targ_y == "rand":
			targ_y = rng.randi_range(0, 4)
		elif targ_y == "p":
			targ_y = player_gridpos.y

		var center_point = Vector2i(min_x + int(targ_x), min_y + int(targ_y))
		for tile in used_cells:
			for i in range(area):
				if (
					(
						tile.x == center_point.x - i
						or tile.x == center_point.x
						or tile.x == center_point.x + i
					)
					and (
						tile.y == center_point.y - i
						or tile.y == center_point.y
						or tile.y == center_point.y + i
					)
				):
					tile_modifiers[tile] = {
						mult_type: mult, "duration": dur, "type": zone_type, "mult": mult
					}
	elif "x" in pos:
		var parts = pos.split("=")
		var min_x = _get_min_x()
		for tile in used_cells:
			if tile.x == min_x + int(parts[1]):
				tile_modifiers[tile] = {
					mult_type: mult, "duration": dur, "type": zone_type, "mult": mult
				}
	elif "y" in pos:
		var parts = pos.split("=")
		#print("parts: ", parts)
		var min_y = _get_min_y()
		for tile in used_cells:
			if tile.y == min_y + int(parts[1]):
				tile_modifiers[tile] = {
					mult_type: mult, "duration": dur, "type": zone_type, "mult": mult
				}

	_update_marker_visuals()
	return marker_info["log"]


func _update_marker_visuals():
	for active_marker in active_markers:
		active_marker.queue_free()
	active_markers.clear()
	for cell: Vector2i in tile_modifiers.keys():
		var marker_info = MARKER_FLAVOURS[tile_modifiers[cell].get("type", "nope")]
		print("Tile modifiers", tile_modifiers)
		var marker = MARKER_PREFAB.instantiate()

		var marker_visual = marker_info.get("visual", "eugh")
		print("visual is ", marker_visual)
		marker.marker_type = marker_visual
		print("Visual is ", marker_visual)
		print("Adding ", marker.marker_type, " marker!")
		marker.tooltip_container = log_container
		var text_val = tile_modifiers[cell].get("mult", 0)
		if tile_modifiers[cell].get("type", "nope") == "dmg_reduc_":
			text_val = int((1 - text_val) * 100)

		marker.marker_info = marker_info["info"].replace("<PUTVALUEHERE>", str(text_val))

		$Battle_root.add_child(marker)
		active_markers.append(marker)
		var world_pos: Vector2 = combat_tilemap.map_to_local(cell)
		marker.global_position = combat_tilemap.to_global(world_pos)
