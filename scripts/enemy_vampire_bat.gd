extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	sprite.play("default")

func _on_hurt_box_area_entered(area: Area2D):
	if area.has_method("collect"):
		area.collect(self)
