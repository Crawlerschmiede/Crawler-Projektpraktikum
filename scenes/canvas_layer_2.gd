extends CanvasLayer

const ENTRY_SCENE := preload("res://scenes/toast/pickup_notification.tscn")

# Optional: gleiche Items in kurzer Zeit zusammenfassen
var merge_window := 0.4
var pending: Dictionary = {}  # item_name -> amount
var merge_timer: Timer

@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	merge_timer = Timer.new()
	merge_timer.one_shot = true
	merge_timer.wait_time = merge_window
	merge_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(merge_timer)
	merge_timer.timeout.connect(_flush_pending)


func show_pickup(item_name: String, amount: int) -> void:
	# 🔥 Sammeln (damit 5 pickups in 0.2s nicht 5 Zeilen spammen)
	pending[item_name] = int(pending.get(item_name, 0)) + amount

	if merge_timer.is_stopped():
		merge_timer.start()


func _flush_pending() -> void:
	for item_name in pending.keys():
		var amount: int = int(pending[item_name])

		var entry := ENTRY_SCENE.instantiate()
		vbox.add_child(entry)

		entry.setup(item_name, amount)
		entry.play()

	# reset
	pending.clear()

	while vbox.get_child_count() > 6:
		var c := vbox.get_child(0)
		c.queue_free()
