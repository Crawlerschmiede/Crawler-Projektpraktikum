extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dialog_panel: Panel = $Panel
@onready var dialog_text: RichTextLabel = $Panel/RichTextLabel
@onready var continue_label: Label = $Panel/Label

var waiting_for_continue := false
var last_dialog_text := ""
var stable_text_time := 0.0
const TEXT_STABLE_SECONDS := 0.12


func _ready() -> void:
	continue_label.visible = false
	animation_player.play(&"Intro")


func _process(_delta: float) -> void:
	if waiting_for_continue:
		return

	if !dialog_panel.visible:
		last_dialog_text = ""
		stable_text_time = 0.0
		return

	var current_text := dialog_text.text
	if current_text != last_dialog_text:
		last_dialog_text = current_text
		stable_text_time = 0.0
		return

	if current_text.strip_edges().is_empty():
		return

	stable_text_time += _delta
	if stable_text_time >= TEXT_STABLE_SECONDS:
		waiting_for_continue = true
		animation_player.speed_scale = 0.0
		continue_label.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if !waiting_for_continue:
		return

	if event.is_action_pressed("dialog_next") or event.is_action_pressed("ui_accept"):
		dialog_panel.visible = false
		continue_label.visible = false
		waiting_for_continue = false
		last_dialog_text = ""
		stable_text_time = 0.0
		animation_player.speed_scale = 1.0
