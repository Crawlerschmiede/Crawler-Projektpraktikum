extends Control

func _ready() -> void:
	# zwingt den UI-Root auf die aktuelle Viewport-Größe
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
