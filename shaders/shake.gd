extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass  # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func shake():
	var tween = create_tween()
	for i in range(5):
		tween.tween_property(
			self,
			"position",
			Vector2(GlobalRNG.randf_range(-10, 10), GlobalRNG.randf_range(-10, 10)),
			0.02
		)
	tween.tween_property(self, "position", Vector2.ZERO, 0.02)
