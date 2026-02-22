extends MoveableEntity

const ROAM_COOLDOWN: float = 2
const CHASE_COOLDOWN: float = 0.5

var roam_timer: float = 5.0
var chase_timer: float = 5.0
var burrowed = false
var chased_pos: Vector2i
var chased_direction: Vector2i
var boss: bool = false
var chosen: Skill
var sprite_type: String = "bat"
var behaviour = "idle"
var chase_target: PlayerCharacter
var chasing: bool = false
var expanded: bool = false

@onready var sight_area: Area2D = $SightArea


func roam():
	if "boss" in types or "immobile" in types:
		return
	if "burrowing" in types:
		if burrowed:
			burrowed = false
			sprite.play("default")
	chasing = false
	var direction_int = 0
	var direction = Vector2i.ZERO
	direction_int = rng.randi_range(0, 3)

	if direction_int == 0:
		direction = Vector2i.RIGHT
	elif direction_int == 1:
		direction = Vector2i.LEFT
	elif direction_int == 2:
		direction = Vector2i.UP
	elif direction_int == 3:
		direction = Vector2i.DOWN
	if "wallbound" in types:
		if is_next_to_wall(grid_pos + direction):
			move_to_tile(direction)
	else:
		move_to_tile(direction)


func is_closer_to_player(
	current_tile: Vector2i, target_tile: Vector2i, chased_tile: Vector2i
) -> bool:
	var curr_distance = abs(current_tile.x - chased_tile.x) + abs(current_tile.y - chased_tile.y)
	var target_distance = abs(target_tile.x - chased_tile.x) + abs(target_tile.y - chased_tile.y)
	return target_distance <= curr_distance


# gdlint: disable=max-returns
func chase():
	if "boss" in types or "immobile" in types:
		return
	if !burrowed:
		chased_pos = chase_target.grid_pos
		chased_direction = chase_target.latest_direction
	var used_animation = animations
	if !chasing:
		if "burrowing" in types:
			if !burrowed:
				if animations != null and animations.has("teleport_start"):
					sprite.play(animations["teleport_start"])
				else:
					# fallback
					sprite.play("default")
				burrowed = true
				return

			var animation_array = null
			var digrection = (chased_direction) * -2
			var targ_dig_pos = chased_pos + digrection
			if used_animation:
				if used_animation["teleport_start"] and used_animation["teleport_end"]:
					animation_array = [used_animation["teleport_end"]]
			await teleport_to_tile(targ_dig_pos, animation_array)
			chasing = true
			burrowed = false
			return

	chasing = true
	var tiles_im_on = []
	var viable_target_tiles = []
	var viable_directions = []
	for tile in my_tiles:
		tiles_im_on.append(grid_pos + tile)
	for tile in my_tiles:
		for direction in DIRECTIONS:
			var target_tile = grid_pos + tile + direction
			if target_tile not in tiles_im_on:
				if not is_cell_walkable(target_tile):
					if "burrowing" in types:
						var burrowable = can_burrow_through(target_tile, direction)
						if not burrowable[0]:
							continue
					else:
						continue
				else:
					if "wallbound" in types:
						if not is_next_to_wall(target_tile):
							continue
					if is_closer_to_player(grid_pos + tile, target_tile, chased_pos):
						viable_target_tiles.append(target_tile)
						viable_directions.append(direction)
	var chosen_direction = GlobalRNG.randi_range(0, len(viable_directions) - 1)
	if len(viable_directions) > 0:
		if "wallbound" in types:
			elongate()
			move_to_tile(viable_directions[chosen_direction])
			elongate()
		else:
			move_to_tile(viable_directions[chosen_direction])
	return


# gdlint: enable=max-returns


func get_best_player() -> PlayerCharacter:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null

	# 1) nur gültige PlayerCharacter
	var valid: Array[PlayerCharacter] = []
	for p in players:
		if p != null and is_instance_valid(p) and p is PlayerCharacter:
			valid.append(p)

	if valid.is_empty():
		return null

	# 2) Nimm den nähesten (falls mehrere)
	var best := valid[0]
	var best_dist := global_position.distance_squared_to(best.global_position)

	for p in valid:
		var d := global_position.distance_squared_to(p.global_position)
		if d < best_dist:
			best = p
			best_dist = d

	return best


func _ready() -> void:
	super_ready(sprite_type, types)

	var p := get_best_player()
	#print("Enemy ready:", name, " found player:", p)

	if p == null:
		push_warning("❌ Enemy found NO player in group 'player' -> cannot connect player_moved")
		return

	if not p.player_moved.is_connected(move_it):
		p.player_moved.connect(move_it)
		#print("✅ Connected player_moved -> move_it")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	chase_timer -= delta
	roam_timer -= delta


func move_it():
	#print("Move1")
	if multi_turn_action == null:
		#print("Move2")
		var saw_player = check_sight()
		if saw_player:
			#print("Move3")
			if "hostile" in types:
				behaviour = "chase"
		else:
			behaviour = "idle"
			chase_target = null

		if behaviour == "idle":
			roam()
		elif behaviour == "chase":
			chase()
	else:
		if multi_turn_action["countdown"] > 0:
			multi_turn_action["countdown"] = multi_turn_action["countdown"] - 1
		else:
			match multi_turn_action["name"]:
				"dig_to":
					teleport_to_tile(multi_turn_action["target"])
					if has_animation(sprite, "dig_up"):
						sprite.play("dig_up")
						await sprite.animation_finished
						sprite.play("default")
			multi_turn_action = null


func check_sight() -> bool:
	var bodies := sight_area.get_overlapping_bodies()

	#print("\n============================")
	#print("👁️ CHECK_SIGHT START: ", self.name, " | grid_pos:", grid_pos)
	#print("SightArea:", sight_area.name, " bodies_count:", bodies.size())

	var saw_player := false
	chase_target = null

	for i in range(bodies.size()):
		var body = bodies[i]

		#print("\n--- BODY #", i, " ----------------------")

		if body == null:
			#print("❌ body is NULL")
			continue

		#print("Node:", body)
		#print("Name:", body.name)
		#print("Class:", body.get_class())
		if body == self:
			#print("⚠️ body is SELF -> skip")
			continue

		# --- Gruppen ausgeben ---
		#print("Groups:", body.get_groups())

		# --- is_player property check ---
		var has_is_player := body.get("is_player") != null or body.has_method("get")  # fallback

		# Sicherer: property via `get`
		var is_player_value = null
		if body.has_method("get"):
			is_player_value = body.get("is_player")
		#print("body.get('is_player'):", is_player_value)

		# --- Gruppencheck ---
		var in_player_group := false
		if body.has_method("is_in_group"):
			in_player_group = body.is_in_group("player")
		#print("Is in group 'player'?", in_player_group)

		# --- Typcheck ---
		var is_player_character := body is PlayerCharacter
		#print("Is PlayerCharacter?", is_player_character)

		# --- Collision Info (falls PhysicsBody2D) ---

		# --- finale Entscheidung ---
		if in_player_group or is_player_character or (("is_player" in body) and body.is_player):
			#print("✅✅✅ PLAYER DETECTED! -> setting chase_target =", body.name)
			if not body.is_hiding() or self.grid_pos.y <= body.grid_pos.y:
				saw_player = true
				chase_target = body
				break

	return saw_player


func decide_attack() -> void:
	var activateable_abilities = []
	for ability in abilities:
		if ability.is_activateable():
			activateable_abilities.append(ability)
	var chosen_index = rng.randi_range(0, len(activateable_abilities) - 1)
	chosen = activateable_abilities[chosen_index]
	print("Next ability is ", chosen.name)


#x and y offset in tiles
func move_sprite(x_offset, y_offset, rotation_deg):
	sprite.rotation_degrees = rotation_deg
	sprite.position.y = y_offset * 16
	sprite.position.x = x_offset * 16


#standard size is 1,1->16px*16px
#i.e. sizes are to be given in TILES
#anchor is... uhh... [U], [D], [L], [R], [U,L], [U,R], [D,L], [D,R], [M]!
#(as in Up, Down, Left, Right, Up-Left...Middle... you get the gist of it)
func resize(x_size: int, y_size: int, anchors, _animation = null, _new_animation = null):
	var coll_shape = $CollisionArea/CollisionShape2D
	var coll_rect = coll_shape.shape.duplicate(true) as RectangleShape2D
	coll_rect.size.x = x_size * 16
	coll_rect.size.y = y_size * 16
	coll_shape.shape = coll_rect
	for anchor in anchors:
		match anchor:
			"U":
				coll_shape.position.y = y_size * 8
			"D":
				coll_shape.position.y = y_size * (-8)
			"L":
				coll_shape.position.x = x_size * 8
			"R":
				coll_shape.position.x = x_size * (-8)
			"M":
				coll_shape.position.x = 0
				coll_shape.position.y = 0
	dimensions = Vector2i(x_size, y_size)
	my_tiles = []
	my_tiles.append(Vector2i(0, 0))
	if y_size > 1 and x_size > 1:
		for i in range(y_size - 1):
			var y_offset = i + 1
			if "D" in anchors:
				y_offset = y_offset * -1
			for j in range(x_size - 1):
				var x_offset = j + 1
				if "R" in anchors:
					x_offset = x_offset * -1
				my_tiles.append(Vector2i(x_offset, y_offset))
	elif x_size > 1:
		for i in range(x_size - 1):
			var offset = i + 1
			if "R" in anchors:
				offset = offset * -1
			my_tiles.append(Vector2i(offset, 0))
	elif y_size > 1:
		for i in range(y_size - 1):
			var offset = i + 1
			if "D" in anchors:
				offset = offset * -1
			my_tiles.append(Vector2i(0, offset))


func elongate():
	var expand = false
	var anchor = "M"
	var x_size = 1
	var y_size = 1
	var x_offset = 0
	var y_offset = 0
	var rotation_deg = 0
	for direction in DIRECTIONS:
		if is_next_to_wall(grid_pos + direction * 2) and not is_next_to_wall(grid_pos + direction):
			expand = true
			match direction:
				Vector2i.UP:
					anchor = "D"
					x_size = 1
					y_size = 3
					x_offset = 0
					y_offset = -1
					rotation_deg = 270
				Vector2i.DOWN:
					anchor = "U"
					x_size = 1
					y_size = 3
					x_offset = 0
					y_offset = 1
					rotation_deg = 90
				Vector2i.LEFT:
					anchor = "R"
					x_size = 3
					y_size = 1
					x_offset = -1
					y_offset = 0
					rotation_deg = 180
				Vector2i.RIGHT:
					anchor = "L"
					x_size = 3
					y_size = 1
					x_offset = 1
					y_offset = 0
					rotation_deg = 0
			if not expanded:
				expanded = true
				resize(x_size, y_size, [anchor])
				move_sprite(x_offset, y_offset, rotation_deg)
				for body in collision_area.get_overlapping_bodies():
					if body == self:
						continue
				sprite.play("expand")
				await sprite.animation_finished
				sprite.play("expanded_idle")
	if not expand and expanded:
		sprite.play_backwards("expand")
		await sprite.animation_finished
		sprite.play("default")
		expanded = false
		resize(1, 1, ["M"])
		move_sprite(0, 0, 0)

	check_collisions()
