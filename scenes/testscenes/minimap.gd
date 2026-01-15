extends CanvasLayer

@export var camera_node: Node2D
@export var player_node: Node2D


func _process(delta: float) -> void:
	# Let camera move with player
	camera_node.position = player_node.position
