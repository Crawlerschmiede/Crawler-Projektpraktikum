extends Area2D

@onready var label_spawn := $LabelSpawn

# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
#	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		label_spawn.add_theme_font_size_override("font_size", 2)
		label_spawn.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if label_spawn.visible== true:
			print("Player left tutorial room, in which he was before.")
			
		label_spawn.visible = false
