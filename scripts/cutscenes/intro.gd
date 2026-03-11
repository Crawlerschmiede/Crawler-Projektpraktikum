extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dialog_panel: Panel = $Panel
@onready var dialog_text: RichTextLabel = $Panel/RichTextLabel
@onready var continue_label: Label = $Panel/Label
@onready var cat_sprite: Node = $PetIntroScene

var waiting_for_continue := false
var last_dialog_text := ""
var stable_text_time := 0.0
var cat_anim_before_pause: StringName = &""
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
		cat_anim_before_pause = _get_cat_animation()
		_set_cat_animation(&"idl")
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
		if cat_anim_before_pause != &"":
			_set_cat_animation(cat_anim_before_pause)
			cat_anim_before_pause = &""
		animation_player.speed_scale = 1.0


func _get_cat_animation() -> StringName:
	if cat_sprite == null:
		return &""
	var current = cat_sprite.get("animation")
	if current is StringName:
		return current
	if current is String:
		return StringName(current)
	return &""


func _set_cat_animation(anim_name: StringName) -> void:
	if cat_sprite == null:
		return
	cat_sprite.set("animation", anim_name)
