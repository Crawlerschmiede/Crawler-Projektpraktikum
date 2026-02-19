extends Node

var item_data: Dictionary
var pos_data: Array = []


func _ready():
	item_data = load_data("res://data/entityData.json")


func load_data(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Datei konnte nicht geöffnet werden: ", file_path)
		return {}

	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)

	if err != OK:
		print("JSON Parse Fehler: ", json.get_error_message())
		return {}

	return json.get_data()


func is_valid_pos(pos: Vector2i, tilemap: TileMapLayer = null) -> bool:
	# Backwards-compatible: reserve if available and return true, false if occupied/invalid
	if not can_reserve_pos(pos, tilemap):
		return false
	reserve_pos(pos)
	return true


func can_reserve_pos(pos: Vector2i, tilemap: TileMapLayer = null) -> bool:
	# Check tile validity (if tilemap provided) and whether it's already reserved
	if tilemap != null:
		if tilemap.get_cell_source_id(pos) == -1:
			return false
		var td := tilemap.get_cell_tile_data(pos)
		if td != null and td.get_custom_data("non_walkable"):
			return false

	if pos_data == null:
		pos_data = []
	return not (pos in pos_data)


func reserve_pos(pos: Vector2i) -> void:
	if pos_data == null:
		pos_data = []
	if not (pos in pos_data):
		pos_data.append(pos)


func reset() -> void:
	# Reload entity data from disk
	item_data = load_data("res://data/entityData.json")
	pos_data = []
