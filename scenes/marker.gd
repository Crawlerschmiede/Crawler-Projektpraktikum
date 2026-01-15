extends Node2D

@export var marker_type: String
@export var marker_info: String
@export var tooltip_container: Node


func _ready() -> void:
	$Area2D.mouse_entered.connect(_on_mouse_entered)
	$Area2D.mouse_exited.connect(_on_mouse_exited)

	var sprite := Sprite2D.new()
	var texture: Texture2D

	match marker_type:
		"danger":
			texture = preload("res://assets/markers/danger_marker.png")
		"heal":
			texture = preload("res://assets/markers/heal_marker.png")

	sprite.texture = texture
	add_child(sprite)

	# Ensure sprite is pickable via collision, not input


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_mouse_entered():
	if tooltip_container != null:
		tooltip_container.tooltips = [marker_type.to_upper(), marker_info]
		tooltip_container.state = "tooltip"
		tooltip_container.changed = true


func _on_mouse_exited():
	if tooltip_container != null:
		tooltip_container.state = "log"
		tooltip_container.changed = true
