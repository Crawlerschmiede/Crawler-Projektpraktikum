extends Node2D

@export var marker_type: String
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var sprite := Sprite2D.new()
	var texture
	match marker_type:
		"danger":
			texture = load("res://assets/markers/danger_marker.png")
		"heal":
			texture = load("res://assets/markers/heal_marker.png")

	sprite.texture = texture

	add_child(sprite)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
