extends Panel

@onready var text_label: RichTextLabel = $RichTextLabel
@onready var next_hint: Control = $NextHint # optional, kann auch fehlen

var lines: Array[String] = []
var index := 0
var active := false

signal finished

func show_lines(new_lines: Array[String]) -> void:
	lines = new_lines
	index = 0
	active = true
	visible = true
	_show_current()

func _unhandled_input(event: InputEvent) -> void:
	if !active:
		return
	if event.is_action_pressed("ui_accept"):
		_next()

func _show_current() -> void:
	text_label.text = lines[index]
	if next_hint:
		next_hint.visible = (index < lines.size() - 1)

func _next() -> void:
	index += 1
	if index >= lines.size():
		active = false
		visible = false
		finished.emit()
	else:
		_show_current()
