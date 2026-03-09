@tool
extends EditorPlugin

const Exporter = preload("res://addons/build_manifest_generator/build_manifest_export.gd")
const ManifestCore = preload("res://tools/manifest_generation_core.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = Exporter.new()
	add_export_plugin(_export_plugin)
	call_deferred("_refresh_manifests_on_editor_load")


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null


func _refresh_manifests_on_editor_load() -> void:
	if ManifestCore.write_all_manifests_to_disk():
		print("BuildManifestGenerator: manifests updated on editor load")
		return
	printerr("BuildManifestGenerator: failed to update manifests on editor load")
