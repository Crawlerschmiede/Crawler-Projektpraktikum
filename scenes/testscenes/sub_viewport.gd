extends SubViewport

@export var player_path: NodePath

var player: Node2D
@onready var cam: Camera2D = $MiniCam

func _ready() -> void:
	world_2d = World2D.new() 
	cam.make_current()
	# nur Layer 2 rendern
	canvas_cull_mask = 1 << 1
	
	_resolve_player()

func _process(_delta: float) -> void:
	if player != null:
		cam.global_position = player.global_position
	else:
		_resolve_player()

func _resolve_player() -> void:
	if player_path != NodePath():
		player = get_node_or_null(player_path) as Node2D
		return

	var found = get_tree().root.find_child("Player", true, false)
	player = found as Node2D if found is Node2D else null
