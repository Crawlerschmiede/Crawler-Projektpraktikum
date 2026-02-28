extends Node

# Autoload singleton to coordinate save/load actions between UI and main
# Register this script as an Autoload with the name `SaveState` in Project Settings -> Autoload.

var load_from_save: bool = false


func reset():
	load_from_save = false
