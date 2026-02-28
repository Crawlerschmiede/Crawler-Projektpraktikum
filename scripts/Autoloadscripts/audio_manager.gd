extends Node

const TRACK_CACHE_PATH := "res://data/audio_tracks.generated.json"

var world_music_overrides: Array[AudioStream] = []
var floor_music_discovered: Array[AudioStream] = []
var generic_fight_music_discovered: Array[AudioStream] = []
var world_music_by_index: Dictionary = {}
var combat_music_by_type: Dictionary = {}
var sfx_events_by_domain: Dictionary = {}
var current_world_index: int = -1
var active_battle_uses_generic_music: bool = false
var in_boss_room: bool = false
var music_player: AudioStreamPlayer = null
var sfx_player: AudioStreamPlayer = null


func _ready() -> void:
	_load_track_cache()
	_ensure_music_player()
	_ensure_sfx_player()
	_connect_game_events()


func configure_world_music(tracks: Array[AudioStream]) -> void:
	world_music_overrides = tracks.duplicate()


func play_world_music(idx: int) -> void:
	current_world_index = idx
	active_battle_uses_generic_music = false
	in_boss_room = false

	var selected_track := _resolve_world_music(idx)
	if selected_track == null:
		push_warning("No floor music assigned for world index: %d" % idx)
		return

	_play_music_stream(selected_track)


func set_in_boss_room(is_boss_room: bool) -> void:
	if in_boss_room == is_boss_room:
		return

	in_boss_room = is_boss_room

	if active_battle_uses_generic_music:
		return

	if in_boss_room:
		_play_boss_room_music()
		return

	_restore_non_battle_music()


func play_sfx_event(domain: String, event_key: String) -> bool:
	var tracks := _get_sfx_event_tracks(domain, event_key)
	if tracks.is_empty():
		return false

	var selected_track := _pick_random_track(tracks)
	if selected_track == null:
		return false

	var player := _ensure_sfx_player()
	player.stream = selected_track
	player.play()
	return true


func enter_battle(enemy: Node) -> void:
	var is_boss := is_boss_enemy(enemy)
	active_battle_uses_generic_music = true

	if is_boss:
		if _play_boss_fight_music(enemy):
			return
		if _play_generic_fight_music():
			return
		active_battle_uses_generic_music = false
		return

	if _play_generic_fight_music():
		return

	active_battle_uses_generic_music = false


func exit_battle() -> void:
	if not active_battle_uses_generic_music:
		return

	active_battle_uses_generic_music = false
	if in_boss_room:
		if _play_boss_room_music():
			return
	_restore_non_battle_music()


func clear_battle_state() -> void:
	active_battle_uses_generic_music = false


func is_boss_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false

	if bool(enemy.get("boss")):
		return true

	var types = enemy.get("types")
	if typeof(types) == TYPE_ARRAY and "boss" in types:
		return true

	return false


func _connect_game_events() -> void:
	if typeof(GameEvents) == TYPE_NIL or GameEvents == null:
		return

	var on_world_loaded := Callable(self, "_on_world_loaded")
	if not GameEvents.world_loaded.is_connected(on_world_loaded):
		GameEvents.world_loaded.connect(on_world_loaded)

	var on_battle_started := Callable(self, "_on_battle_started")
	if not GameEvents.battle_started.is_connected(on_battle_started):
		GameEvents.battle_started.connect(on_battle_started)

	var on_battle_ended := Callable(self, "_on_battle_ended")
	if not GameEvents.battle_ended.is_connected(on_battle_ended):
		GameEvents.battle_ended.connect(on_battle_ended)

	var on_game_over := Callable(self, "_on_game_over")
	if not GameEvents.game_over.is_connected(on_game_over):
		GameEvents.game_over.connect(on_game_over)


func _on_world_loaded(idx: int) -> void:
	play_world_music(idx)


func _on_battle_started(enemy: Node, _is_boss: bool) -> void:
	enter_battle(enemy)


func _on_battle_ended(_victory: bool, _enemy: Node, _is_boss: bool) -> void:
	exit_battle()


func _on_game_over() -> void:
	clear_battle_state()
	in_boss_room = false
	_play_game_over_music()


func _resolve_world_music(idx: int) -> AudioStream:
	if idx >= 0 and idx < world_music_overrides.size() and world_music_overrides[idx] != null:
		return world_music_overrides[idx]
	if world_music_by_index.has(idx):
		var configured_track: Variant = world_music_by_index[idx]
		if configured_track is AudioStream:
			return configured_track
	if idx >= 0 and idx < floor_music_discovered.size():
		return floor_music_discovered[idx]
	return null


func _ensure_music_player() -> AudioStreamPlayer:
	if music_player != null and is_instance_valid(music_player):
		music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		return music_player

	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Master"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	return music_player


func _ensure_sfx_player() -> AudioStreamPlayer:
	if sfx_player != null and is_instance_valid(sfx_player):
		sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
		return sfx_player

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "Master"
	sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx_player)
	return sfx_player


func _play_music_stream(stream: AudioStream) -> void:
	if stream == null:
		return

	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	var player := _ensure_music_player()
	if player.stream == stream and player.playing:
		return

	player.stream = stream
	player.play()


func _play_generic_fight_music() -> bool:
	var configured_tracks: Array[AudioStream] = _get_combat_tracks("generic")
	if not configured_tracks.is_empty():
		_play_music_stream(_pick_random_track(configured_tracks))
		return true

	if generic_fight_music_discovered.is_empty():
		push_warning("No generic fight music assigned")
		return false

	_play_music_stream(_pick_random_track(generic_fight_music_discovered))
	return true


func _play_boss_fight_music(enemy: Node) -> bool:
	var boss_key := _resolve_boss_music_key(enemy)
	if not boss_key.is_empty():
		var specific_tracks := _get_combat_tracks(boss_key)
		if not specific_tracks.is_empty():
			_debug_boss_music_selection("specific", boss_key, specific_tracks.size())
			_play_music_stream(_pick_random_track(specific_tracks))
			return true

	var default_tracks := _get_combat_tracks("boss_default")
	if not default_tracks.is_empty():
		_debug_boss_music_selection("default-fallback", boss_key, default_tracks.size())
		_play_music_stream(_pick_random_track(default_tracks))
		return true

	var fallback_tracks := _get_combat_tracks("boss")
	if not fallback_tracks.is_empty():
		_debug_boss_music_selection("boss-fallback", boss_key, fallback_tracks.size())
		_play_music_stream(_pick_random_track(fallback_tracks))
		return true

	_debug_boss_music_selection("none", boss_key, 0)

	return false


func _restore_non_battle_music() -> void:
	if in_boss_room and _play_boss_room_music():
		return

	if current_world_index >= 0:
		play_world_music(current_world_index)
		return

	var player := _ensure_music_player()
	if player.playing:
		player.stop()


func _play_game_over_music() -> bool:
	var game_over_tracks := _get_sfx_event_tracks("ui", "game_over")
	if game_over_tracks.is_empty():
		return false

	_play_music_stream(_pick_random_track(game_over_tracks))
	return true


func _play_boss_room_music() -> bool:
	var room_tracks := _get_sfx_event_tracks("world", "boss_room")
	if not room_tracks.is_empty():
		_play_music_stream(_pick_random_track(room_tracks))
		return true

	var default_tracks := _get_combat_tracks("boss_default")
	if not default_tracks.is_empty():
		_play_music_stream(_pick_random_track(default_tracks))
		return true

	var fallback_tracks := _get_combat_tracks("boss")
	if fallback_tracks.is_empty():
		return false

	_play_music_stream(_pick_random_track(fallback_tracks))
	return true


func _load_track_cache() -> void:
	floor_music_discovered.clear()
	generic_fight_music_discovered.clear()
	world_music_by_index.clear()
	combat_music_by_type.clear()
	sfx_events_by_domain.clear()
	var used_new_schema := false
	var used_legacy_fallback := false

	if not FileAccess.file_exists(TRACK_CACHE_PATH):
		_debug_audio_manifest_status(false, false, "manifest file missing")
		return

	var file := FileAccess.open(TRACK_CACHE_PATH, FileAccess.READ)
	if file == null:
		_debug_audio_manifest_status(false, false, "failed to open manifest")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		_debug_audio_manifest_status(false, false, "manifest parse did not return dictionary")
		return

	var parsed_dict: Dictionary = parsed
	var music_section_raw: Variant = parsed_dict.get("music", {})
	if typeof(music_section_raw) == TYPE_DICTIONARY:
		var world_section_raw: Variant = music_section_raw.get("world_by_index", {})
		if typeof(world_section_raw) == TYPE_DICTIONARY:
			world_music_by_index = _index_dictionary_to_streams(world_section_raw)
			used_new_schema = used_new_schema or not world_music_by_index.is_empty()

		var combat_section_raw: Variant = music_section_raw.get("combat_by_type", {})
		if typeof(combat_section_raw) == TYPE_DICTIONARY:
			combat_music_by_type = _combat_dictionary_to_streams(combat_section_raw)
			used_new_schema = used_new_schema or not combat_music_by_type.is_empty()

	var sfx_events_raw: Variant = parsed_dict.get("sfx_events", {})
	if typeof(sfx_events_raw) == TYPE_DICTIONARY:
		sfx_events_by_domain = _sfx_events_dictionary_to_streams(sfx_events_raw)

	var world_music_by_index_raw: Variant = parsed_dict.get("world_music_by_index", {})
	if typeof(world_music_by_index_raw) == TYPE_DICTIONARY:
		if world_music_by_index.is_empty():
			world_music_by_index = _index_dictionary_to_streams(world_music_by_index_raw)
		used_new_schema = used_new_schema or not world_music_by_index.is_empty()

	var combat_music_by_type_raw: Variant = parsed_dict.get("combat_music_by_type", {})
	if typeof(combat_music_by_type_raw) == TYPE_DICTIONARY:
		if combat_music_by_type.is_empty():
			combat_music_by_type = _combat_dictionary_to_streams(combat_music_by_type_raw)
		used_new_schema = used_new_schema or not combat_music_by_type.is_empty()

	var floor_paths_raw: Array = parsed_dict.get("floor_music_paths", [])
	if typeof(floor_paths_raw) == TYPE_ARRAY:
		floor_music_discovered = _paths_to_streams(floor_paths_raw)

	var fight_paths_raw: Array = parsed_dict.get("generic_fight_music_paths", [])
	if typeof(fight_paths_raw) == TYPE_ARRAY:
		generic_fight_music_discovered = _paths_to_streams(fight_paths_raw)

	if world_music_by_index.is_empty() and not floor_music_discovered.is_empty():
		for i in range(floor_music_discovered.size()):
			if floor_music_discovered[i] != null:
				world_music_by_index[i] = floor_music_discovered[i]
		used_legacy_fallback = true

	if combat_music_by_type.is_empty() and not generic_fight_music_discovered.is_empty():
		combat_music_by_type["generic"] = generic_fight_music_discovered.duplicate()
		used_legacy_fallback = true

	_debug_audio_manifest_status(used_new_schema, used_legacy_fallback, "loaded")


func _debug_audio_manifest_status(
	used_new_schema: bool, used_legacy_fallback: bool, reason: String
) -> void:
	if not OS.is_debug_build():
		return

	var mode := "empty"
	if used_new_schema and used_legacy_fallback:
		mode = "mixed"
	elif used_new_schema:
		mode = "new-schema"
	elif used_legacy_fallback:
		mode = "legacy-fallback"

	var world_count := world_music_by_index.size()
	var combat_pool_count := combat_music_by_type.size()
	var generic_count := _get_combat_tracks("generic").size()
	print(
		(
			"[AudioManager] track cache %s (%s) world=%d combat_pools=%d generic=%d"
			% [reason, mode, world_count, combat_pool_count, generic_count]
		)
	)


func _debug_boss_music_selection(mode: String, boss_key: String, pool_size: int) -> void:
	if not OS.is_debug_build():
		return

	print(
		"[AudioManager] boss battle music mode=%s boss_key=%s pool=%d" % [mode, boss_key, pool_size]
	)


func _paths_to_streams(paths: Array) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for path_value in paths:
		if typeof(path_value) != TYPE_STRING:
			continue
		var path := String(path_value)
		if path.is_empty():
			continue
		var loaded: Resource = load(path)
		if loaded is AudioStream:
			out.append(loaded)
	return out


func _index_dictionary_to_streams(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in raw.keys():
		var idx := int(str(key))
		var value: Variant = raw[key]
		if typeof(value) == TYPE_ARRAY:
			var tracks := _paths_to_streams(_unique_string_array(value))
			if not tracks.is_empty():
				out[idx] = tracks[0]
		elif typeof(value) == TYPE_STRING:
			var single_tracks := _paths_to_streams([value])
			if not single_tracks.is_empty():
				out[idx] = single_tracks[0]
	return out


func _combat_dictionary_to_streams(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in raw.keys():
		var value: Variant = raw[key]
		var normalized_key := String(key).to_lower()

		if normalized_key == "boss" and typeof(value) == TYPE_DICTIONARY:
			var merged_boss_tracks: Array[AudioStream] = []
			for boss_key in value.keys():
				var boss_value: Variant = value[boss_key]
				if typeof(boss_value) != TYPE_ARRAY:
					continue
				var boss_tracks: Array[AudioStream] = _paths_to_streams(
					_unique_string_array(boss_value)
				)
				if boss_tracks.is_empty():
					continue

				var normalized_boss_key := String(boss_key).to_lower()
				if normalized_boss_key == "default":
					out["boss_default"] = boss_tracks
				else:
					out[normalized_boss_key] = boss_tracks

				_append_unique_streams(merged_boss_tracks, boss_tracks)

			if not merged_boss_tracks.is_empty():
				out["boss"] = merged_boss_tracks
			continue

		if typeof(value) != TYPE_ARRAY:
			continue
		var tracks: Array[AudioStream] = _paths_to_streams(_unique_string_array(value))
		if tracks.is_empty():
			continue
		out[normalized_key] = tracks
	return out


func _sfx_events_dictionary_to_streams(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for domain in raw.keys():
		var domain_value: Variant = raw[domain]
		if typeof(domain_value) != TYPE_DICTIONARY:
			continue
		var domain_map: Dictionary = {}
		for event_key in domain_value.keys():
			var event_value: Variant = domain_value[event_key]
			if typeof(event_value) != TYPE_ARRAY:
				continue
			var tracks := _paths_to_streams(_unique_string_array(event_value))
			if tracks.is_empty():
				continue
			domain_map[String(event_key).to_lower()] = tracks
		if not domain_map.is_empty():
			out[String(domain).to_lower()] = domain_map
	return out


func _unique_string_array(values: Array) -> Array:
	var out: Array = []
	for value in values:
		if typeof(value) != TYPE_STRING:
			continue
		if value in out:
			continue
		out.append(value)
	return out


func _append_unique_streams(target: Array[AudioStream], additions: Array[AudioStream]) -> void:
	for track in additions:
		if track == null:
			continue
		if track in target:
			continue
		target.append(track)


func _get_sfx_event_tracks(domain: String, event_key: String) -> Array[AudioStream]:
	var domain_name := domain.to_lower()
	if not sfx_events_by_domain.has(domain_name):
		return []

	var domain_raw: Variant = sfx_events_by_domain[domain_name]
	if typeof(domain_raw) != TYPE_DICTIONARY:
		return []

	var domain_map: Dictionary = domain_raw
	var normalized_event := event_key.to_lower()
	if not domain_map.has(normalized_event):
		return []

	var tracks_raw: Variant = domain_map[normalized_event]
	if tracks_raw is Array[AudioStream]:
		return tracks_raw

	return []


func _get_combat_tracks(track_type: String) -> Array[AudioStream]:
	var normalized := track_type.to_lower()
	if not combat_music_by_type.has(normalized):
		return []
	var tracks: Variant = combat_music_by_type[normalized]
	if tracks is Array[AudioStream]:
		return tracks
	return []


func _pick_random_track(tracks: Array[AudioStream]) -> AudioStream:
	if tracks.is_empty():
		return null
	var rng := GlobalRNG.get_rng()
	return tracks[rng.randi_range(0, tracks.size() - 1)]


func _resolve_boss_music_key(enemy: Node) -> String:
	if enemy == null or not is_instance_valid(enemy):
		return ""

	var sprite_type_value: Variant = ""
	if enemy.has_method("get_property_list"):
		for property_data in enemy.get_property_list():
			if str(property_data.get("name", "")) == "sprite_type":
				sprite_type_value = enemy.get("sprite_type")
				break

	var sprite_type := String(sprite_type_value).to_lower()
	if sprite_type.contains("necro"):
		return "necro"
	if sprite_type.contains("orc"):
		return "orc"
	if sprite_type.contains("plant"):
		return "plant"
	if sprite_type.contains("wendigo"):
		return "wendigo"

	return ""
