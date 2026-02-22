extends Panel

var glow_shader = preload("res://shaders/glitterglow.gdshader")
var select_texture = preload("res://assets/menu/Frames/Ram Deco All.png")

var select_layer: TextureRect
var is_selected: bool = false


func _ready():
	select_layer = TextureRect.new()
	select_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	select_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_layer.texture = select_texture
	select_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	select_layer.stretch_mode = TextureRect.STRETCH_SCALE

	select_layer.material = CanvasItemMaterial.new()
	select_layer.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	select_layer.visible = false
	add_child(select_layer)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_selected(value: bool) -> void:
	is_selected = value
	if select_layer != null:
		select_layer.visible = is_selected


func _on_mouse_entered():
	self.material = ShaderMaterial.new()
	self.material.shader = glow_shader


func _on_mouse_exited():
	self.material = null
