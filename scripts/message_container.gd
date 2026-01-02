extends ScrollContainer

@onready var message_list = $VBoxContainer

@export var combat_log = []
@export var tooltips = []
@export var state = "log"
@export var changed: bool = false
var last_state = "log"


func add_log_event(message:String):
	combat_log.append(message)
	_fill_list(combat_log)
	

func _clear_list() -> void:
	for child in message_list.get_children():
		child.queue_free()

func _add_label(text: String) -> void:
	var b := Label.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 10)
	message_list.add_child(b)
	

func _fill_list(messages: Array) -> void:
	_clear_list()
	for message in messages:
		_add_label(message)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	combat_log.append("The battle begins!")
	_fill_list(combat_log)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if state!=last_state or changed:
		print("clearing")
		_clear_list()
		print("switched from "+last_state+" to " + state)
		match state:
			"log":
				_fill_list(combat_log)
			"tooltip":
				_fill_list(tooltips)
				
				
		last_state = state
		changed=false
		
		
