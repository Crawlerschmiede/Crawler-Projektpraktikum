extends Panel

@onready var text_label: RichTextLabel = $RichTextLabel
@onready var next_arrow: CanvasItem = $NextArrow

signal finished

var lines: Array[String] = []
var index := 0
var active := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 0
	offset_right = 0
	offset_bottom = 0
	offset_top = -180  # Höhe der Box
	visible = false

func show_lines(new_lines: Array[String]) -> void:
	lines = new_lines
	index = 0
	active = true
	visible = true
	next_arrow.visible = true
	_show_current()
	

func _unhandled_input(event: InputEvent) -> void:
	if !active:
		return

	if event.is_action_pressed("dialog_next"):
		_next_line()


func _show_current() -> void:
	text_label.text = lines[index]


func _next_line() -> void:
	index += 1

	if index >= lines.size():
		active = false
		visible = false
		finished.emit()
	else:
		_show_current()
