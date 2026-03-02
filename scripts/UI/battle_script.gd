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
	enemy_sprite = create_battle_sprite(enemy)
	player_sprite = create_battle_sprite(player)
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
	# We're doing this twice in case we extend a range and then end up in it
	# because of that or something similar.
	for i in range(2):
		update_passives()
	enemy.decide_attack()
	enemy_prepare_turn()


func create_battle_sprite(from_actor: CharacterBody2D) -> AnimatedSprite2D:
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


func enemy_prepare_turn():
	# TODO: very low tech; clears everything (ok for 1-turn effects).
	# Anything longer-term will need something more robust.
	tile_modifiers.clear()
	for active_marker in active_markers:
		active_marker.queue_free()
	active_markers.clear()
	log_container.add_log_event("The enemy prepares its Skill " + enemy.chosen.name + "!")
	#print(enemy, " prepares its Skill ", enemy.chosen.name, "!")
	var preps = enemy.chosen.prep_skill(enemy, player, self)
	update_passives(0, true)
	for prep in preps:
		log_container.add_log_event(prep)
	player.refill_actions()
	enemy.refill_actions()
	update_passives()


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
			happened = enemy.chosen.activate_skill(enemy, player, self)
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
			enemy_prepare_turn()
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
				ability.activate_followup()
		next_turn = []
		if extra_stuff[0]:
			player_turn()
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


func player_turn():
	if not active:
		return
	skill_ui.update()
	skill_ui.player_turn = true


func force_stop() -> void:
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


func update_passives(depth = 0, prep = false):
	trigger_passives(player.abilities, player, enemy, self, depth, prep)
	#trigger_passives(player.items, player, enemy, self)	#will items have passives?
	trigger_passives(enemy.abilities, enemy, player, self, depth, prep)


func trigger_passives(abilities, user, target, battle, depth, prep):
	print("Triggering passives at depth ", depth)
	for ability in abilities:
		if ability.is_passive:
			if ability.is_activateable(user, target, self):
				print("Activated the passive effect ", ability.name)
				if prep:
					ability.prep_skill(user, target, battle)
				else:
					ability.activate_skill(user, target, battle, depth)
				print("Active passive effects: ", user.get_alterations())
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


func battle_over():
	if enemy == null or not is_instance_valid(enemy) or enemy.hp <= 0:
		return true
	if player == null or not is_instance_valid(player) or player.hp <= 0:
		return true
	return false


func cell_exists(cell: Vector2i) -> bool:
	# Get the tile data from the TileMapLayer at the given cell
	var tile_data = combat_tilemap.get_cell_tile_data(cell)
	if tile_data == null:
		return false  # No tile = not walkable (outside map)
	return true


func move_player(direction: String, distance: int):
	var dir = ""
	var basics = ["u", "d", "l", "r"]
	var new_cell := player_gridpos
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
				return []

		new_cell = player_gridpos + delta
	elif "rnd" in direction:
		var ranges = ["short", "medium", "long"]
		var parts = direction.split("_")
		var area = parts[1]
		var from_to = []
		var min_y = get_min_y()
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
			return move_player(new_dir, distance)

	if !cell_exists(new_cell):
		return "Attempting to move " + dir + ", the player only pushed against the wall"
	player_gridpos = new_cell
	player_sprite.position = combat_tilemap.map_to_local(player_gridpos)
	check_curr_tile_mods()
	return "Player moved " + dir


func is_player_in_range(y_from_to) -> bool:
	var min_y = get_min_y()
	return player_gridpos.y >= min_y + y_from_to[0] and player_gridpos.y <= min_y + y_from_to[1]


func get_player_range_dmg_mult():
	var dmg_mult: float = 1.0
	var calculated_range = player.get_used_range()
	var base_tiles = [0, 0]
	var player_y = player_gridpos.y - get_min_y()
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


func check_curr_tile_mods():
	var active_placement_effects = tile_modifiers.get(player_gridpos, {})
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
				enemy.hp.take_damage(modifier_value)
			"heal_good":
				player.heal(modifier_value)
			"heal_bad":
				enemy.heal(modifier_value)
	over = check_victory()


func get_min_x():
	var min_x = 99999999999999
	for tile in used_cells:
		if tile.x < min_x:
			min_x = tile.x
	return min_x


func get_min_y():
	var min_y = 99999999999999
	for tile in used_cells:
		if tile.y < min_y:
			min_y = tile.y
	return min_y


func apply_zones(zone_type, mult, pos, _dur, direction):
	print("Applying ", zone_type, " zones at ", pos)
	# NOTE: duration currently unused (effects are 1-turn only).
	var mult_type = zone_type + direction
	var marker_info = MARKER_FLAVOURS[zone_type]
	var marker_visual = marker_info["visual"]
	if pos == "player_x":
		for tile in used_cells:
			if tile.x == player_gridpos.x:
				tile_modifiers[tile] = {mult_type: mult}
	elif pos == "player_y":
		for tile in used_cells:
			if tile.y == player_gridpos.y:
				tile_modifiers[tile] = {mult_type: mult}
	elif pos == "player_pos":
		for tile in used_cells:
			if tile == player_gridpos:
				tile_modifiers[tile] = {mult_type: mult}
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
				tile_modifiers[tile] = {mult_type: mult}
	elif "area" in pos:  #expecting a string like "area||<x>||<y>||<size>"
		var min_x = get_min_x()
		var min_y = get_min_y()
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
					tile_modifiers[tile] = {mult_type: mult}
	elif "x" in pos:
		var parts = pos.split("=")
		var min_x = get_min_x()
		for tile in used_cells:
			if tile.x == min_x + int(parts[1]):
				tile_modifiers[tile] = {mult_type: mult}
	elif "y" in pos:
		var parts = pos.split("=")
		#print("parts: ", parts)
		var min_y = get_min_y()
		for tile in used_cells:
			if tile.y == min_y + int(parts[1]):
				tile_modifiers[tile] = {mult_type: mult}

	for cell: Vector2i in tile_modifiers.keys():
		print("Tile modifiers", tile_modifiers)
		var marker = MARKER_PREFAB.instantiate()
		var correct = false
		for key in tile_modifiers[cell].keys():
			if zone_type in key:
				correct = true
		if not correct:
			continue

		marker.marker_type = marker_visual
		print("Visual is ", marker_visual)
		print("Adding ", marker.marker_type, " marker!")
		marker.tooltip_container = log_container
		var text_val = mult
		if zone_type == "dmg_reduc_":
			text_val = int((1 - mult) * 100)
		marker.marker_info = marker_info["info"].replace("<PUTVALUEHERE>", str(text_val))

		$Battle_root.add_child(marker)
		active_markers.append(marker)
		var world_pos: Vector2 = combat_tilemap.map_to_local(cell)
		marker.global_position = combat_tilemap.to_global(world_pos)
	return marker_info["log"]
