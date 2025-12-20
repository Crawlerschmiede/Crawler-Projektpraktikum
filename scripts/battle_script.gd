extends CanvasLayer

@onready var enemy_marker = $Battle_root/EnemyPosition
@onready var player_marker = $Battle_root/PlayerPosition
@onready var combat_tilemap = $Battle_root/TileMapLayer
@onready var skill_ui = $Battle_root/ItemList

@export var player:Node
@export var enemy:Node

signal player_loss
signal player_victory

var player_gridpos:Vector2i

func _ready():
	var enemy_sprite = create_battle_sprite(enemy)
	var player_sprite = create_battle_sprite(player)
	player_sprite.animation = "idle_up"
	enemy_marker.add_child(enemy_sprite)
	player_gridpos = combat_tilemap.local_to_map(player_marker.position)
	combat_tilemap.add_child(player_sprite)
	player_sprite.position = combat_tilemap.map_to_local(player_gridpos)
	skill_ui.setup(player, enemy)
	if skill_ui.has_signal("player_turn_done"):
		# Ensure the connection is safe and only happens once
		skill_ui.player_turn_done.connect(enemy_turn)
	enemy.decide_attack()

	
	
func create_battle_sprite(from_actor: CharacterBody2D) -> AnimatedSprite2D:
	print("getting sprite for ", from_actor)
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
	
func enemy_turn():
	var over = check_victory()
	if !over:
		print(enemy, " activates its Skill ", enemy.chosen.name, "!")
		enemy.chosen.activate_skill(enemy, player)
		enemy.decide_attack()
		skill_ui.player_turn=true
		check_victory()
	
func check_victory():
	if enemy.HP <=0:
		player_victory.emit()
		return true
	if player.HP<=0:
		player_loss.emit()
		return true
	return false
