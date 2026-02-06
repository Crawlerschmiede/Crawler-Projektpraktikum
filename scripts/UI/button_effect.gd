extends Button

@export var outline_color: Color = Color("ffeca5ff")
@export var outline_size: int = 1

var _hovered := false
var _focused := false


func _ready():
	add_theme_constant_override("outline_size", 0)
	add_theme_color_override("font_outline_color", outline_color)

	add_theme_stylebox_override("focus", StyleBoxEmpty.new())  # <-- removes box

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	focus_mode = Control.FOCUS_ALL

	pivot_offset = size / 2


# ==========================
# SHARED ANIMATION
# ==========================


func _animate_hover(on: bool):
	pivot_offset = size / 2

	var tween = create_tween()

	if on:
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_method(set_outline_thickness, 0, outline_size, 0.1)
		modulate = Color(1.2, 1.2, 1.2)
	else:
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
		tween.parallel().tween_method(set_outline_thickness, outline_size, 0, 0.1)
		modulate = Color(1, 1, 1)


# ==========================
# MOUSE
# ==========================


func _on_mouse_entered():
	_hovered = true
	_animate_hover(true)


func _on_mouse_exited():
	_hovered = false

	if not _focused:
		_animate_hover(false)


# ==========================
# FOCUS (KEYBOARD/GAMEPAD)
# ==========================


func _on_focus_entered():
	_focused = true
	_animate_hover(true)


func _on_focus_exited():
	_focused = false

	if not _hovered:
		_animate_hover(false)


# ==========================
# CLICK
# ==========================


func _on_button_down():
	scale = Vector2(0.95, 0.95)


func _on_button_up():
	if _hovered or _focused:
		scale = Vector2(1.1, 1.1)
	else:
		scale = Vector2(1.0, 1.0)


# ==========================
# OUTLINE
# ==========================


func set_outline_thickness(value: int):
	add_theme_constant_override("outline_size", value)
