@tool
extends EditorScript

const ManifestCore = preload("res://tools/manifest_generation_core.gd")


func _run() -> void:
	if ManifestCore.write_all_manifests_to_disk():
		pass  # print("Manifest generation completed.")
		pass  # print("Manifest written: ", ManifestCore.ROOM_MANIFEST_PATH)
		pass  # print("Audio manifest written: ", ManifestCore.AUDIO_MANIFEST_PATH)
		return

	push_error("Failed to write one or more manifests")
