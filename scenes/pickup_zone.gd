extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# nur Items einsammeln (über Gruppe)
	if body.is_in_group("item"):
		print("Item entered")
		# Wenn Item eine Methode pick_up_item(player) besitzt
		if body.has_method("pick_up_item"):
			body.pick_up_item(get_parent())  # parent = Player
