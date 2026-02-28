@tool
extends EditorExportPlugin

const ManifestUtils = preload("res://scripts/Mapgenerator/helpers/room_manifest_utils.gd")
const AUDIO_MANIFEST_PATH := "res://data/audio_tracks.generated.json"
const SFX_DIR := "res://assets/sfx"

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
	var manifest := ManifestUtils.build_manifest()
	var json_text := JSON.stringify(manifest, "\t")
	_manifest_bytes = json_text.to_utf8_buffer()
	add_file(ManifestUtils.ROOM_MANIFEST_PATH, _manifest_bytes, false)
	print("Manifest added to export: ", ManifestUtils.ROOM_MANIFEST_PATH)

	_generate_audio_manifest()

	var f := FileAccess.open(ManifestUtils.ROOM_MANIFEST_PATH, FileAccess.WRITE)
	if f == null:
		var err := FileAccess.get_open_error()
		push_warning(
			"Manifest write skipped (export already has embedded manifest): %s" % error_string(err)
		)
		return
	f.store_string(json_text)
	f.close()


func _generate_audio_manifest() -> void:
	var audio_manifest := _build_audio_manifest()
	var json_text := JSON.stringify(audio_manifest, "\t")
	_audio_manifest_bytes = json_text.to_utf8_buffer()
	add_file(AUDIO_MANIFEST_PATH, _audio_manifest_bytes, false)
	print("Audio manifest added to export: ", AUDIO_MANIFEST_PATH)

	var f := FileAccess.open(AUDIO_MANIFEST_PATH, FileAccess.WRITE)
	if f == null:
		var err := FileAccess.get_open_error()
		push_warning(
			(
				"Audio manifest write skipped (export already has embedded manifest): %s"
				% error_string(err)
			)
		)
		return
	f.store_string(json_text)
	f.close()


func _build_audio_manifest() -> Dictionary:
	var floor_paths: Array[String] = []
	var generic_paths: Array[String] = []

	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return {
			"floor_music_paths": floor_paths,
			"generic_fight_music_paths": generic_paths,
		}

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			continue

		var lower := name.to_lower()
		if not (lower.ends_with(".mp3") or lower.ends_with(".ogg") or lower.ends_with(".wav")):
			continue

		if lower.begins_with("(floor-"):
			var close_idx := lower.find(")")
			if close_idx > 7:
				var floor_num_str := lower.substr(7, close_idx - 7)
				if floor_num_str.is_valid_int():
					var floor_idx := maxi(int(floor_num_str) - 1, 0)
					while floor_paths.size() <= floor_idx:
						floor_paths.append("")
					floor_paths[floor_idx] = "%s/%s" % [SFX_DIR, name]
		elif lower.begins_with("(normal-fight)"):
			generic_paths.append("%s/%s" % [SFX_DIR, name])

	dir.list_dir_end()
	generic_paths.sort()

	return {
		"floor_music_paths": floor_paths,
		"generic_fight_music_paths": generic_paths,
	}
