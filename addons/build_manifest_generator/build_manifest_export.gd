@tool
extends EditorExportPlugin

const ManifestCore = preload("res://tools/manifest_generation_core.gd")

var _manifest_bytes: PackedByteArray = PackedByteArray()
var _audio_manifest_bytes: PackedByteArray = PackedByteArray()
var _export_started := false


func _export_begin(
	_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int
) -> void:
	if _export_started:
		return
	_export_started = true
	_generate_manifests()


func _export_end() -> void:
	_export_started = false


func _get_name() -> String:
	return "BuildManifestGenerator"


func _generate_manifests() -> void:
	var room_manifest: Dictionary = ManifestCore.build_room_manifest()
	_manifest_bytes = ManifestCore.manifest_bytes(room_manifest)
	add_file(ManifestCore.ROOM_MANIFEST_PATH, _manifest_bytes, false)
	print("Manifest added to export: ", ManifestCore.ROOM_MANIFEST_PATH)

	var audio_manifest: Dictionary = ManifestCore.build_audio_manifest()
	_audio_manifest_bytes = ManifestCore.manifest_bytes(audio_manifest)
	add_file(ManifestCore.AUDIO_MANIFEST_PATH, _audio_manifest_bytes, false)
	print("Audio manifest added to export: ", ManifestCore.AUDIO_MANIFEST_PATH)

	if not ManifestCore.write_manifest_to_disk(ManifestCore.ROOM_MANIFEST_PATH, room_manifest):
		var room_err := FileAccess.get_open_error()
		push_warning(
			(
				"Manifest write skipped (export already has embedded manifest): %s"
				% error_string(room_err)
			)
		)

	if not ManifestCore.write_manifest_to_disk(ManifestCore.AUDIO_MANIFEST_PATH, audio_manifest):
		var audio_err := FileAccess.get_open_error()
		push_warning(
			(
				"Audio manifest write skipped (export already has embedded manifest): %s"
				% error_string(audio_err)
			)
		)
