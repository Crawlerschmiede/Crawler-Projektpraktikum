extends AnimatedSprite2D

signal clicked(node_name)
@export var click_scale_reduction: float = 0.1 
@onready var original_scale: Vector2 = scale

var is_hovering: bool = false
#var clicked: bool = false

func _process(_delta):
	# 1. Calculate the bounds (same logic as your click fix)
	var frame_texture = sprite_frames.get_frame_texture(animation, frame)
	var frame_size = frame_texture.get_size()
	var rect = Rect2(-frame_size / 2, frame_size) # Assumes 'Centered' is ON
	
	# 2. Check if mouse is hovering
	if rect.has_point(get_local_mouse_position()):
		if not is_hovering: # Only trigger once when entering
			is_hovering = true
			play("hover")
	else:
		if is_hovering: # Only trigger once when leaving
			is_hovering = false
			play("idle")
			
func _ready():
	play("idle")
	set_process_unhandled_input(true)

func _on_mouse_entered():
	play("hover")

func _on_mouse_exited():
	play("idle")
	scale = original_scale 

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if get_rect_compat().has_point(get_local_mouse_position()):
			clicked.emit(self.name) # Tell the parent!
				
		var frame_size = sprite_frames.get_frame_texture(animation, frame).get_size()
		var rect = Rect2(-frame_size / 2, frame_size) 
		
		if rect.has_point(get_local_mouse_position()):
			if event.pressed:
				scale = original_scale * (1.0 - click_scale_reduction)
			else:
				scale = original_scale
				print("Clicked!")
				
func get_rect_compat():
	var fs = sprite_frames.get_frame_texture(animation, frame).get_size()
	return Rect2(-fs/2, fs)
