@tool
extends EditorExportPlugin

const ManifestUtils = preload("res://scripts/Mapgenerator/helpers/room_manifest_utils.gd")

var _manifest_bytes: PackedByteArray = PackedByteArray()
var _export_started := false


func _export_begin(
	_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int
) -> void:
	if _export_started:
		return
	_export_started = true
	_generate_manifest()


func _export_end() -> void:
	_export_started = false


func _get_name() -> String:
	return "RoomManifestGenerator"


func _generate_manifest() -> void:
	var manifest := ManifestUtils.build_manifest()
	var json_text := JSON.stringify(manifest, "\t")
	_manifest_bytes = json_text.to_utf8_buffer()
	add_file(ManifestUtils.ROOM_MANIFEST_PATH, _manifest_bytes, false)
	print("Manifest added to export: ", ManifestUtils.ROOM_MANIFEST_PATH)

	var f := FileAccess.open(ManifestUtils.ROOM_MANIFEST_PATH, FileAccess.WRITE)
	if f == null:
		var err := FileAccess.get_open_error()
		push_warning(
			"Manifest write skipped (export already has embedded manifest): %s" % error_string(err)
		)
		return
	f.store_string(json_text)
	f.close()
