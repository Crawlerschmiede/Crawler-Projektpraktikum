class_name EnemyVampireBat

extends MoveableEntity

const ROAM_COOLDOWN: float = 2
const CHASE_COOLDOWN: float = 0.5

var roam_timer: float = 5.0
var chase_timer: float = 5.0
var burrowed = false
var chased_pos: Vector2i
var chased_direction: Vector2i

var chosen: Skill
var sprite_type: String = "bat"
var behaviour = "idle"
var chase_target: PlayerCharacter
var chasing: bool = false

@onready var sight_area: Area2D = $SightArea


func roam():
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


func chase():
	if !burrowed:
		chased_pos = chase_target.grid_pos
		chased_direction = chase_target.latest_direction
	var x_move = Vector2i.ZERO
	var y_move = Vector2i.ZERO
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
			else:
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
	if chased_pos.x < grid_pos.x:
		x_move = Vector2i.LEFT
	if chased_pos.x > grid_pos.x:
		x_move = Vector2i.RIGHT
	if chased_pos.y < grid_pos.y:
		y_move = Vector2i.UP
	if chased_pos.y > grid_pos.y:
		y_move = Vector2i.DOWN
	if "wallbound" in types:
		if is_next_to_wall(grid_pos + x_move) and x_move != Vector2i.ZERO:
			move_to_tile(x_move)
			chase_timer = CHASE_COOLDOWN
			return
		if is_next_to_wall(grid_pos + y_move) and y_move != Vector2i.ZERO:
			move_to_tile(y_move)
			chase_timer = CHASE_COOLDOWN
			return
	elif "burrowing" in types:
		if tilemap.get_cell_tile_data(grid_pos + x_move) and x_move != Vector2i.ZERO:
			move_to_tile(x_move)
			chase_timer = CHASE_COOLDOWN
			return
		if tilemap.get_cell_tile_data(grid_pos + y_move) and y_move != Vector2i.ZERO:
			move_to_tile(y_move)
			chase_timer = CHASE_COOLDOWN
			return
	else:
		if (
			tilemap.get_cell_tile_data(grid_pos + x_move)
			and !tilemap.get_cell_tile_data(grid_pos + x_move).get_custom_data("non_walkable")
			and x_move != Vector2i.ZERO
		):
			move_to_tile(x_move)
			chase_timer = CHASE_COOLDOWN
			return
		if (
			tilemap.get_cell_tile_data(grid_pos + y_move)
			and !tilemap.get_cell_tile_data(grid_pos + y_move).get_custom_data("non_walkable")
			and y_move != Vector2i.ZERO
		):
			move_to_tile(y_move)
			chase_timer = CHASE_COOLDOWN
			return


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
	print("Enemy ready:", name, " found player:", p)

	if p == null:
		push_warning("❌ Enemy found NO player in group 'player' -> cannot connect player_moved")
		return

	if not p.player_moved.is_connected(move_it):
		p.player_moved.connect(move_it)
		print("✅ Connected player_moved -> move_it")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	chase_timer -= delta
	roam_timer -= delta


func move_it():
	print("Move1")
	if multi_turn_action == null:
		print("Move2")
		var saw_player = check_sight()
		if saw_player:
			print("Move3")
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

	print("\n============================")
	print("👁️ CHECK_SIGHT START: ", self.name, " | grid_pos:", grid_pos)
	print("SightArea:", sight_area.name, " bodies_count:", bodies.size())

	var saw_player := false
	chase_target = null

	for i in range(bodies.size()):
		var body = bodies[i]

		print("\n--- BODY #", i, " ----------------------")

		if body == null:
			print("❌ body is NULL")
			continue

		print("Node:", body)
		print("Name:", body.name)
		print("Class:", body.get_class())
		print(
			"SceneFile:",
			body.scene_file_path if "scene_file_path" in body else "(no scene_file_path)"
		)

		if body == self:
			print("⚠️ body is SELF -> skip")
			continue

		# --- Gruppen ausgeben ---
		print("Groups:", body.get_groups())

		# --- is_player property check ---
		var has_is_player := body.get("is_player") != null or body.has_method("get")  # fallback
		print(
			"Has property 'is_player'?",
			body.has_meta("is_player") if body.has_method("has_meta") else "?",
			" | raw get('is_player'):",
			body.get("is_player")
		)

		# Sicherer: property via `get`
		var is_player_value = null
		if body.has_method("get"):
			is_player_value = body.get("is_player")
		print("body.get('is_player'):", is_player_value)

		# Direkter Zugriff (kann crashen wenn property nicht existiert)
		if "is_player" in body:
			print("✅ 'is_player' in body → body.is_player =", body.is_player)
		else:
			print("❌ 'is_player' NOT in body")

		# --- Gruppencheck ---
		var in_player_group := false
		if body.has_method("is_in_group"):
			in_player_group = body.is_in_group("player")
		print("Is in group 'player'?", in_player_group)

		# --- Typcheck ---
		var is_player_character := body is PlayerCharacter
		print("Is PlayerCharacter?", is_player_character)

		# --- Collision Info (falls PhysicsBody2D) ---
		if body is PhysicsBody2D:
			print(
				"PhysicsBody2D collision_layer:",
				body.collision_layer,
				" collision_mask:",
				body.collision_mask
			)
		elif body is Area2D:
			print(
				"Area2D collision_layer:",
				body.collision_layer,
				" collision_mask:",
				body.collision_mask
			)

		# --- finale Entscheidung ---
		if in_player_group or is_player_character or (("is_player" in body) and body.is_player):
			print("✅✅✅ PLAYER DETECTED! -> setting chase_target =", body.name)
			saw_player = true
			chase_target = body
			break
		else:
			print("❌ not player (did not match any criteria)")

	print("\nRESULT: saw_player =", saw_player, " chase_target =", chase_target)
	print("============================\n")

	return saw_player


func decide_attack() -> void:
	var chosen_index = rng.randi_range(0, len(abilities) - 1)
	chosen = abilities[chosen_index]
	print("Next ability is ", chosen.name)
