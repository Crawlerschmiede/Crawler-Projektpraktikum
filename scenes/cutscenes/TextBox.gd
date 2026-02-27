extends Panel

@onready var text_label: RichTextLabel = $Margin/RichTextLabel
@onready var next_icon: Control = $NextIcon

@export var blink_min_alpha := 0.2
@export var blink_time := 0.35

signal finished

var lines: Array[String] = []
var index := 0
var active := false
var blink_tween: Tween

func _ready() -> void:
	visible = false

	# Icon immer über Text
	next_icon.z_as_relative = false
	next_icon.z_index = 100
	next_icon.visible = false

func show_lines(new_lines: Array) -> void:
	# robust: akzeptiert Array, Array[String], PackedStringArray
	lines.clear()
	for x in new_lines:
		lines.append(str(x))

	index = 0
	active = true
	visible = true
	text_label.text = lines[index]

func _unhandled_input(event: InputEvent) -> void:
	if !active:
		return

	if event.is_action_pressed("dialog_next"):
		_next_line()


func _next_line() -> void:
	index += 1
	if index >= lines.size():
		active = false
		visible = false
		finished.emit()
	else:
		text_label.text = lines[index]
