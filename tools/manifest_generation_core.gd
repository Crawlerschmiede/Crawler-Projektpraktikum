const ManifestUtils = preload("res://scripts/Mapgenerator/helpers/room_manifest_utils.gd")
const ROOM_MANIFEST_PATH := ManifestUtils.ROOM_MANIFEST_PATH
const AUDIO_MANIFEST_PATH := "res://data/audio_tracks.generated.json"
const SFX_DIR := "res://assets/sfx"


static func build_room_manifest() -> Dictionary:
	return ManifestUtils.build_manifest()


static func build_audio_manifest() -> Dictionary:
	var floor_paths: Array = []
	var generic_paths: Array[String] = []
	var boss_music_by_type: Dictionary = {}

	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return {
			"schema_version": 1,
			"music":
			{
				"world_by_index": {},
				"combat_by_type": {},
			},
			"sfx_events": {},
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
						floor_paths.append([])
					var floor_track_path := "%s/%s" % [SFX_DIR, name]
					var floor_tracks: Array = floor_paths[floor_idx]
					_append_unique_string(floor_tracks, floor_track_path)
					floor_tracks.sort()
					floor_paths[floor_idx] = floor_tracks
		elif lower.begins_with("(normal-fight)"):
			var normal_path := "%s/%s" % [SFX_DIR, name]
			_append_unique_string(generic_paths, normal_path)
		elif lower.begins_with("(boss-"):
			var boss_close_idx := lower.find(")")
			if boss_close_idx > 6:
				var boss_key := lower.substr(6, boss_close_idx - 6)
				if boss_key == "floor" or boss_key == "boss":
					boss_key = "default"
				var boss_path := "%s/%s" % [SFX_DIR, name]
				_append_boss_track(boss_music_by_type, boss_key, boss_path)

	dir.list_dir_end()
	generic_paths.sort()

	var world_music_by_index := _array_to_index_dictionary(floor_paths)
	var combat_music_by_type: Dictionary = {}
	if not generic_paths.is_empty():
		combat_music_by_type["generic"] = generic_paths
	if not boss_music_by_type.is_empty():
		combat_music_by_type["boss"] = boss_music_by_type

	return {
		"schema_version": 1,
		"music":
		{
			"world_by_index": world_music_by_index,
			"combat_by_type": combat_music_by_type,
		},
		"sfx_events": {},
	}


static func write_all_manifests_to_disk() -> bool:
	var room_ok := write_manifest_to_disk(ROOM_MANIFEST_PATH, build_room_manifest())
	var audio_ok := write_manifest_to_disk(AUDIO_MANIFEST_PATH, build_audio_manifest())
	return room_ok and audio_ok


static func write_manifest_to_disk(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


static func manifest_bytes(payload: Dictionary) -> PackedByteArray:
	return JSON.stringify(payload, "\t").to_utf8_buffer()


static func _append_boss_track(boss_map: Dictionary, key: String, path: String) -> void:
	if not boss_map.has(key):
		boss_map[key] = []
	var tracks: Array = boss_map[key]
	if path in tracks:
		return
	tracks.append(path)
	tracks.sort()
	boss_map[key] = tracks


static func _append_unique_string(target: Array, value: String) -> void:
	if value in target:
		return
	target.append(value)


static func _array_to_index_dictionary(paths: Array) -> Dictionary:
	var out: Dictionary = {}
	for i in range(paths.size()):
		if typeof(paths[i]) != TYPE_ARRAY:
			continue
		var tracks_raw: Array = paths[i]
		var tracks: Array[String] = []
		for track in tracks_raw:
			if typeof(track) != TYPE_STRING:
				continue
			if track in tracks:
				continue
			tracks.append(track)
		if tracks.is_empty():
			continue
		tracks.sort()
		out[str(i)] = tracks
	return out
