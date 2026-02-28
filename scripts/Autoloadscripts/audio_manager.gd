extends Node

const TRACK_CACHE_PATH := "res://data/audio_tracks.generated.json"

var world_music_overrides: Array[AudioStream] = []
var floor_music_discovered: Array[AudioStream] = []
var generic_fight_music_discovered: Array[AudioStream] = []
var current_world_index: int = -1
var active_battle_uses_generic_music: bool = false
var music_player: AudioStreamPlayer = null


func _ready() -> void:
	_load_track_cache()
	_ensure_music_player()


func configure_world_music(tracks: Array[AudioStream]) -> void:
	world_music_overrides = tracks.duplicate()


func play_world_music(idx: int) -> void:
	current_world_index = idx
	active_battle_uses_generic_music = false

	var selected_track := _resolve_world_music(idx)
	if selected_track == null:
		push_warning("No floor music assigned for world index: %d" % idx)
		return

	_play_music_stream(selected_track)


func enter_battle(enemy: Node) -> void:
	active_battle_uses_generic_music = not _is_boss_enemy(enemy)
	if not active_battle_uses_generic_music:
		return

	_play_generic_fight_music()


func exit_battle() -> void:
	if not active_battle_uses_generic_music:
		return

	active_battle_uses_generic_music = false
	_restore_non_battle_music()


func clear_battle_state() -> void:
	active_battle_uses_generic_music = false


func _is_boss_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false

	if bool(enemy.get("boss")):
		return true

	var types = enemy.get("types")
	if typeof(types) == TYPE_ARRAY and "boss" in types:
		return true

	return false


func _resolve_world_music(idx: int) -> AudioStream:
	if idx >= 0 and idx < world_music_overrides.size() and world_music_overrides[idx] != null:
		return world_music_overrides[idx]
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


func _play_generic_fight_music() -> void:
	if generic_fight_music_discovered.is_empty():
		push_warning("No generic fight music assigned")
		return

	var rng := GlobalRNG.get_rng()
	var selected_track: AudioStream = generic_fight_music_discovered[rng.randi_range(
		0, generic_fight_music_discovered.size() - 1
	)]
	_play_music_stream(selected_track)


func _restore_non_battle_music() -> void:
	if current_world_index >= 0:
		play_world_music(current_world_index)
		return

	var player := _ensure_music_player()
	if player.playing:
		player.stop()


func _load_track_cache() -> void:
	floor_music_discovered.clear()
	generic_fight_music_discovered.clear()

	if not FileAccess.file_exists(TRACK_CACHE_PATH):
		return

	var file := FileAccess.open(TRACK_CACHE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var parsed_dict: Dictionary = parsed

	var floor_paths_raw: Array = parsed_dict.get("floor_music_paths", [])
	if typeof(floor_paths_raw) == TYPE_ARRAY:
		floor_music_discovered = _paths_to_streams(floor_paths_raw)

	var fight_paths_raw: Array = parsed_dict.get("generic_fight_music_paths", [])
	if typeof(fight_paths_raw) == TYPE_ARRAY:
		generic_fight_music_discovered = _paths_to_streams(fight_paths_raw)


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
