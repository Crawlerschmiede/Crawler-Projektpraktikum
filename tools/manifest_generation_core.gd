const ManifestUtils = preload("res://scripts/Mapgenerator/helpers/room_manifest_utils.gd")
const ROOM_MANIFEST_PATH := ManifestUtils.ROOM_MANIFEST_PATH
const AUDIO_MANIFEST_PATH := "res://data/audio_tracks.generated.json"
const SFX_DIR := "res://assets/sfx"


static func build_room_manifest() -> Dictionary:
	return ManifestUtils.build_manifest()


static func build_audio_manifest() -> Dictionary:
	var floor_paths: Array = []
	var tutorial_floor_paths: Array[String] = []
	var generic_paths: Array[String] = []
	var boss_music_by_type: Dictionary = {}
	var exit_hover_paths: Array[String] = []
	var settings_hover_paths: Array[String] = []
	var start_new_hover_paths: Array[String] = []
	var game_over_paths: Array[String] = []
	var boss_room_event_paths: Array[String] = []
	var final_boss_room_event_paths: Array[String] = []

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
					var floor_idx := maxi(int(floor_num_str), 0)
					while floor_paths.size() <= floor_idx:
						floor_paths.append([])
					var floor_track_path := "%s/%s" % [SFX_DIR, name]
					var floor_tracks: Array = floor_paths[floor_idx]
					_append_unique_string(floor_tracks, floor_track_path)
					floor_tracks.sort()
					floor_paths[floor_idx] = floor_tracks
				elif floor_num_str == "tutorial":
					_append_unique_string(tutorial_floor_paths, "%s/%s" % [SFX_DIR, name])
				elif floor_num_str == "boss":
					var final_boss_room_path := "%s/%s" % [SFX_DIR, name]
					_append_unique_string(final_boss_room_event_paths, final_boss_room_path)
		elif lower.begins_with("(normal-fight)"):
			var normal_path := "%s/%s" % [SFX_DIR, name]
			_append_unique_string(generic_paths, normal_path)
		elif lower.begins_with("(boss-"):
			var boss_close_idx := lower.find(")")
			if boss_close_idx > 6:
				var boss_key := lower.substr(6, boss_close_idx - 6)
				var boss_path := "%s/%s" % [SFX_DIR, name]
				if boss_key == "room":
					_append_unique_string(boss_room_event_paths, boss_path)
					continue
				if boss_key == "room" or boss_key == "boss":
					boss_key = "default"
				_append_boss_track(boss_music_by_type, boss_key, boss_path)
		elif lower == "exit.mp3":
			_append_unique_string(exit_hover_paths, "%s/%s" % [SFX_DIR, name])
		elif lower == "settings.mp3":
			_append_unique_string(settings_hover_paths, "%s/%s" % [SFX_DIR, name])
		elif lower == "start new.mp3":
			_append_unique_string(start_new_hover_paths, "%s/%s" % [SFX_DIR, name])
		elif lower == "game_over_fv.mp3":
			_append_unique_string(game_over_paths, "%s/%s" % [SFX_DIR, name])

	dir.list_dir_end()
	generic_paths.sort()

	var exit_folder_paths := _collect_audio_variants_from_subdir("Exit")
	if not exit_folder_paths.is_empty():
		exit_hover_paths = exit_folder_paths

	var settings_folder_paths := _collect_audio_variants_from_subdir("Settings")
	if not settings_folder_paths.is_empty():
		settings_hover_paths = settings_folder_paths

	var start_new_folder_paths := _collect_audio_variants_from_subdir("Start New")
	if not start_new_folder_paths.is_empty():
		start_new_hover_paths = start_new_folder_paths

	var game_over_folder_paths := _collect_audio_variants_from_subdir("Game Over")
	if not game_over_folder_paths.is_empty():
		game_over_paths = game_over_folder_paths

	exit_hover_paths.sort()
	settings_hover_paths.sort()
	start_new_hover_paths.sort()
	game_over_paths.sort()

	var world_music_by_index := _array_to_index_dictionary(floor_paths)
	if not tutorial_floor_paths.is_empty():
		tutorial_floor_paths.sort()
		world_music_by_index["0"] = tutorial_floor_paths
	var combat_music_by_type: Dictionary = {}
	if not generic_paths.is_empty():
		combat_music_by_type["generic"] = generic_paths
	if not boss_music_by_type.is_empty():
		combat_music_by_type["boss"] = boss_music_by_type

	var sfx_events: Dictionary = {}
	var menu_events: Dictionary = {}
	if not exit_hover_paths.is_empty():
		menu_events["hover_exit"] = exit_hover_paths
	if not settings_hover_paths.is_empty():
		menu_events["hover_settings"] = settings_hover_paths
	if not start_new_hover_paths.is_empty():
		menu_events["hover_start_new"] = start_new_hover_paths
	if not menu_events.is_empty():
		sfx_events["menu"] = menu_events

	var ui_events: Dictionary = {}
	if not game_over_paths.is_empty():
		ui_events["game_over"] = game_over_paths
	if not ui_events.is_empty():
		sfx_events["ui"] = ui_events

	var world_events: Dictionary = {}
	if not boss_room_event_paths.is_empty():
		boss_room_event_paths.sort()
		world_events["boss_room"] = boss_room_event_paths
	if not final_boss_room_event_paths.is_empty():
		final_boss_room_event_paths.sort()
		world_events["final_boss_room"] = final_boss_room_event_paths
	if not world_events.is_empty():
		sfx_events["world"] = world_events

	return {
		"schema_version": 1,
		"music":
		{
			"world_by_index": world_music_by_index,
			"combat_by_type": combat_music_by_type,
		},
		"sfx_events": sfx_events,
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


static func _collect_audio_variants_from_subdir(subdir_name: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("%s/%s" % [SFX_DIR, subdir_name])
	if dir == null:
		return out

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

		_append_unique_string(out, "%s/%s/%s" % [SFX_DIR, subdir_name, name])

	dir.list_dir_end()
	out.sort()
	return out


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
