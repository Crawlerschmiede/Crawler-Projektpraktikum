extends Node

var item_data: Dictionary


func _ready():
	item_data = load_data("res://data/itemData.json")


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


func reset() -> void:
	# Reload item data from disk
	item_data = load_data("res://data/itemData.json")
