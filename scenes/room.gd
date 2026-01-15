extends Node2D

var overlapping: bool = false
var overlap_count: int = 0


func _ready() -> void:
	$Area2D.area_entered.connect(_on_overlap_enter)
	$Area2D.area_exited.connect(_on_overlap_exit)


func _on_overlap_enter(area: Area2D) -> void:
	if area.get_parent() == self:
		return

	overlap_count += 1
	overlapping = overlap_count > 0


func _on_overlap_exit(area: Area2D) -> void:
	if area.get_parent() == self:
		return

	overlap_count = max(0, overlap_count - 1)
	overlapping = overlap_count > 0
