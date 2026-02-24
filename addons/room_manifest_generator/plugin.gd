@tool
extends EditorPlugin

const Exporter = preload("res://addons/room_manifest_generator/room_manifest_export.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = Exporter.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
