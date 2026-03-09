extends Node

const TRACK_CACHE_PATH := "res://data/audio_tracks.generated.json"
const AudioBusHelper := preload("res://scripts/Autoloadscripts/audio_bus_helper.gd")
const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"
const MASTER_BUS_NAME := "Master"

const DEFAULT_MUSIC_CONTEXT_LEVEL_DB := {
	"world": 0.0,
	"combat_generic": 0.0,
	"combat_boss": 0.0,
	"boss_room": 0.0,
	"game_over": 0.0,
}

const DEFAULT_SFX_DOMAIN_LEVEL_DB := {
	"menu": 20.0,
	"ui": 0.0,
	"world": 0.0,
}

var world_music_overrides: Array[AudioStream] = []
var floor_music_discovered: Array[AudioStream] = []
var generic_fight_music_discovered: Array[AudioStream] = []
var world_music_by_index: Dictionary = {}
var combat_music_by_type: Dictionary = {}
var sfx_events_by_domain: Dictionary = {}
var music_track_level_db_by_path: Dictionary = {}
var sfx_track_level_db_by_path: Dictionary = {}
var music_context_level_db: Dictionary = {}
var sfx_domain_level_db: Dictionary = {}
var current_world_index: int = -1
var active_battle_uses_generic_music: bool = false
var in_boss_room: bool = false
var in_final_boss_room: bool = false
var music_player: AudioStreamPlayer = null
var sfx_player: AudioStreamPlayer = null


func _ready() -> void:
	_load_track_cache()
	_ensure_audio_buses()
	_ensure_music_player()
	_ensure_sfx_player()
	_connect_game_events()


func configure_world_music(tracks: Array[AudioStream]) -> void:
	world_music_overrides = tracks.duplicate()


func play_world_music(idx: int) -> void:
	current_world_index = idx
	active_battle_uses_generic_music = false
	in_boss_room = false
	in_final_boss_room = false

	var selected_track := _resolve_world_music(idx)
	if selected_track == null:
		push_warning("No floor music assigned for world index: %d" % idx)
		return

	_play_music_stream(selected_track)


func set_in_boss_room(is_boss_room: bool) -> void:
	if not is_boss_room and in_final_boss_room:
		in_final_boss_room = false

	if in_boss_room == is_boss_room:
		return

	in_boss_room = is_boss_room

	if active_battle_uses_generic_music:
		return

	if in_boss_room:
		_play_boss_room_music()
		return

	_restore_non_battle_music()


func set_in_final_boss_room(is_final_boss_room: bool) -> void:
	in_final_boss_room = is_final_boss_room
	if is_final_boss_room:
		set_in_boss_room(true)
		return

	if not in_boss_room:
		_restore_non_battle_music()


func play_sfx_event(domain: String, event_key: String) -> bool:
	var tracks := _get_sfx_event_tracks(domain, event_key)
	if tracks.is_empty():
		return false

	# TODO: Preprocess SFX in Audacity/DAW (split variants + loudness normalize);
	# keep final in-game balancing on Godot audio buses.
	var selected_track := _pick_random_track(tracks)
	if selected_track == null:
		return false

	var player := _ensure_sfx_player()
	player.stream = selected_track
	player.volume_db = _resolve_sfx_volume_db(selected_track, domain)
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
	in_final_boss_room = false
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
		music_player.bus = MUSIC_BUS_NAME
		music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		return music_player

	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = MUSIC_BUS_NAME
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	return music_player


func _ensure_sfx_player() -> AudioStreamPlayer:
	if sfx_player != null and is_instance_valid(sfx_player):
		sfx_player.bus = SFX_BUS_NAME
		sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
		return sfx_player

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = SFX_BUS_NAME
	sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx_player)
	return sfx_player


func _play_music_stream(stream: AudioStream, context_key: String = "world") -> void:
	if stream == null:
		return

	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	var player := _ensure_music_player()
	player.volume_db = _resolve_music_volume_db(stream, context_key)
	if player.stream == stream and player.playing:
		return

	player.stream = stream
	player.play()


func _play_generic_fight_music() -> bool:
	var configured_tracks: Array[AudioStream] = _get_combat_tracks("generic")
	if not configured_tracks.is_empty():
		_play_music_stream(_pick_random_track(configured_tracks), "combat_generic")
		return true

	if generic_fight_music_discovered.is_empty():
		push_warning("No generic fight music assigned")
		return false

	_play_music_stream(_pick_random_track(generic_fight_music_discovered), "combat_generic")
	return true


func _play_boss_fight_music(enemy: Node) -> bool:
	var boss_key := _resolve_boss_music_key(enemy)
	if not boss_key.is_empty():
		var specific_tracks := _get_combat_tracks(boss_key)
		if not specific_tracks.is_empty():
			_debug_boss_music_selection("specific", boss_key, specific_tracks.size())
			_play_music_stream(_pick_random_track(specific_tracks), "combat_boss")
			return true

	if in_final_boss_room:
		var final_room_tracks := _get_sfx_event_tracks("world", "final_boss_room")
		if not final_room_tracks.is_empty():
			_debug_boss_music_selection("final-room-fallback", boss_key, final_room_tracks.size())
			_play_music_stream(_pick_random_track(final_room_tracks), "combat_boss")
			return true

	var normal_room_tracks := _get_sfx_event_tracks("world", "boss_room")
	if not normal_room_tracks.is_empty():
		_debug_boss_music_selection("boss-room-fallback", boss_key, normal_room_tracks.size())
		_play_music_stream(_pick_random_track(normal_room_tracks), "combat_boss")
		return true

	var fallback_tracks := _get_combat_tracks("boss")
	if not fallback_tracks.is_empty():
		_debug_boss_music_selection("boss-fallback", boss_key, fallback_tracks.size())
		_play_music_stream(_pick_random_track(fallback_tracks), "combat_boss")
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

	_play_music_stream(_pick_random_track(game_over_tracks), "game_over")
	return true


func _play_boss_room_music() -> bool:
	var room_event_key := "boss_room"
	if in_final_boss_room:
		room_event_key = "final_boss_room"

	var room_tracks := _get_sfx_event_tracks("world", room_event_key)
	if not room_tracks.is_empty():
		_play_music_stream(_pick_random_track(room_tracks), "boss_room")
		return true

	if current_world_index >= 0:
		var floor_track := _resolve_world_music(current_world_index)
		if floor_track != null:
			_play_music_stream(floor_track, "world")
			return true

	var fallback_tracks := _get_combat_tracks("boss")
	if fallback_tracks.is_empty():
		return false

	_play_music_stream(_pick_random_track(fallback_tracks), "combat_boss")
	return true


func _load_track_cache() -> void:
	floor_music_discovered.clear()
	generic_fight_music_discovered.clear()
	world_music_by_index.clear()
	combat_music_by_type.clear()
	sfx_events_by_domain.clear()
	music_track_level_db_by_path.clear()
	sfx_track_level_db_by_path.clear()
	music_context_level_db = DEFAULT_MUSIC_CONTEXT_LEVEL_DB.duplicate(true)
	sfx_domain_level_db = DEFAULT_SFX_DOMAIN_LEVEL_DB.duplicate(true)
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

	var leveling_raw: Variant = parsed_dict.get("leveling_db", {})
	if typeof(leveling_raw) == TYPE_DICTIONARY:
		music_track_level_db_by_path = _path_level_dictionary(leveling_raw.get("music_by_path", {}))
		sfx_track_level_db_by_path = _path_level_dictionary(leveling_raw.get("sfx_by_path", {}))
		music_context_level_db = _merge_level_maps(
			music_context_level_db, _path_level_dictionary(leveling_raw.get("music_context_db", {}))
		)
		sfx_domain_level_db = _merge_level_maps(
			sfx_domain_level_db, _path_level_dictionary(leveling_raw.get("sfx_domain_db", {}))
		)

	var music_levels_legacy: Variant = parsed_dict.get("music_track_level_db_by_path", {})
	if music_track_level_db_by_path.is_empty() and typeof(music_levels_legacy) == TYPE_DICTIONARY:
		music_track_level_db_by_path = _path_level_dictionary(music_levels_legacy)

	var sfx_levels_legacy: Variant = parsed_dict.get("sfx_track_level_db_by_path", {})
	if sfx_track_level_db_by_path.is_empty() and typeof(sfx_levels_legacy) == TYPE_DICTIONARY:
		sfx_track_level_db_by_path = _path_level_dictionary(sfx_levels_legacy)

	var music_context_legacy: Variant = parsed_dict.get("music_context_level_db", {})
	if typeof(music_context_legacy) == TYPE_DICTIONARY:
		music_context_level_db = _merge_level_maps(
			music_context_level_db, _path_level_dictionary(music_context_legacy)
		)

	var sfx_domain_legacy: Variant = parsed_dict.get("sfx_domain_level_db", {})
	if typeof(sfx_domain_legacy) == TYPE_DICTIONARY:
		sfx_domain_level_db = _merge_level_maps(
			sfx_domain_level_db, _path_level_dictionary(sfx_domain_legacy)
		)

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


func _debug_boss_music_selection(mode: String, boss_key: String, pool_size: int) -> void:
	if not OS.is_debug_build():
		return


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


func _path_level_dictionary(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}

	var source: Dictionary = raw
	var out: Dictionary = {}
	for key in source.keys():
		var path := String(key)
		if path.is_empty():
			continue

		var value: Variant = source[key]
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			out[path] = float(value)
	return out


func _resolve_music_track_level_db(stream: AudioStream) -> float:
	return _resolve_track_level_db(stream, music_track_level_db_by_path)


func _resolve_sfx_track_level_db(stream: AudioStream) -> float:
	return _resolve_track_level_db(stream, sfx_track_level_db_by_path)


func _resolve_music_volume_db(stream: AudioStream, context_key: String) -> float:
	return (
		_resolve_music_track_level_db(stream)
		+ _resolve_level_for_key(music_context_level_db, context_key)
	)


func _resolve_sfx_volume_db(stream: AudioStream, domain: String) -> float:
	return _resolve_sfx_track_level_db(stream) + _resolve_level_for_key(sfx_domain_level_db, domain)


func _resolve_level_for_key(level_map: Dictionary, key: String) -> float:
	var normalized := key.to_lower()
	if not level_map.has(normalized):
		return 0.0
	var value: Variant = level_map[normalized]
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return 0.0


func _merge_level_maps(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	for key in overrides.keys():
		merged[String(key).to_lower()] = float(overrides[key])
	return merged


func _resolve_track_level_db(stream: AudioStream, level_map: Dictionary) -> float:
	if stream == null:
		return 0.0

	var path := stream.resource_path
	if path.is_empty():
		return 0.0

	if not level_map.has(path):
		return 0.0

	var value: Variant = level_map[path]
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)

	return 0.0


func _ensure_audio_buses() -> void:
	AudioBusHelper.ensure_bus(MUSIC_BUS_NAME, MASTER_BUS_NAME)
	AudioBusHelper.ensure_bus(SFX_BUS_NAME, MASTER_BUS_NAME)


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
