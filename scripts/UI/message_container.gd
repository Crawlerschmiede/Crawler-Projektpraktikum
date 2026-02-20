extends ScrollContainer

@export var combat_log: Array = []
@export var tooltips: Array = []
@export var state: String = "log"
@export var changed: bool = false
var up_to_date: bool = true
var custom_font = load("res://assets/font/PixelPurl.ttf")
var last_state: String = "log"
var list_index: int = 0
const message_delay := 0.5
var message_timer: float = 0.5

@onready var message_list = $VBoxContainer


func add_log_event(message: String):
	combat_log.append(message)
	changed = true


func _clear_list() -> void:
	for child in message_list.get_children():
		child.queue_free()


func _add_label(text: String) -> void:
	var b := Label.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	#b.add_theme_font_size_override("font_size", 10)
	b.add_theme_font_override("font", custom_font)
	message_list.add_child(b)
	await get_tree().process_frame
	scroll_vertical = get_v_scroll_bar().max_value


func _fill_list(messages: Array, delta) -> void:
	message_timer += delta
	if message_timer >= message_delay:
		message_timer = 0
		if list_index < len(messages):
			_add_label(messages[list_index])
			list_index += 1
			if list_index == len(messages):
				up_to_date = true
		else:
			up_to_date = true


func reset():
	combat_log = []
	_clear_list()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	combat_log.append("The battle begins!")
	_clear_list()
	changed = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if state != last_state or changed:
		#print("clearing")
		_clear_list()
		up_to_date = false
		list_index = 0
		last_state = state
		changed = false
		#print("switched from " + last_state + " to " + state)
	if not up_to_date:
		match state:
			"log":
				_fill_list(combat_log, _delta)
			"tooltip":
				_fill_list(tooltips, _delta)
