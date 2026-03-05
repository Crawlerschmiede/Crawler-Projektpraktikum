class_name AudioBusHelper
extends RefCounted


static func ensure_bus(bus_name: String, send_name: String = "Master") -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	AudioServer.add_bus(AudioServer.bus_count)
	var new_bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(new_bus_index, bus_name)

	if AudioServer.get_bus_index(send_name) >= 0:
		AudioServer.set_bus_send(new_bus_index, send_name)


static func ensure_default_buses() -> void:
	ensure_bus("Music", "Master")
	ensure_bus("SFX", "Master")
