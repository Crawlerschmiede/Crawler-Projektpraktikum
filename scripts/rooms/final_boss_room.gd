extends Node2D

@onready var bg_music = $bg_music


func _ready():
	if bg_music:
		bg_music.play(2.0)
