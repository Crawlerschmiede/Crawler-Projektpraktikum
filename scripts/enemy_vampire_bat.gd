extends CharacterBody2D

const ENTITY_SPAWN = preload("res://scripts/entity_spawn.gd")

# --- Exports ---
@export var tilemap_path: NodePath

# --- Member variables ---
var grid_pos: Vector2i
var tilemap: TileMapLayer
var latest_direction = Vector2i.DOWN

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var entity_spawn = ENTITY_SPAWN.new()
	tilemap = get_node(tilemap_path)
	position = entity_spawn.entity_spawn(tilemap)
	grid_pos = tilemap.local_to_map(position)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	sprite.play("default")
