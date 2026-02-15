@tool
extends EditorScript

const ManifestUtils = preload("res://scripts/Mapgenerator/helpers/room_manifest_utils.gd")


func _run() -> void:
	var manifest := ManifestUtils.build_manifest()
	var f := FileAccess.open(ManifestUtils.ROOM_MANIFEST_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Failed to write manifest: " + ManifestUtils.ROOM_MANIFEST_PATH)
		return
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	print("Manifest written: ", ManifestUtils.ROOM_MANIFEST_PATH)
