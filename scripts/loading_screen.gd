extends CanvasLayer

const TIPS: Array[String] = [
	"Torches keep the shadows at bay, but they don't last forever.",
	"Listen closely; some walls sound hollow when struck.",
	"Rare loot is often guarded by the deadliest traps.",
	"Don't forget to pack extra rations for long descents.",
	"Not all monsters are hostile; some just want to trade."
]

# Progress UI
@export var generator_path: NodePath

var _last_pct: int = 0
var _first_progress_received: bool = false
@onready var loading_char = $LoadingCharacter
@onready var tip_label = $TipLabel
# Updated to reference TextureProgressBar correctly
@onready var progress_bar: TextureProgressBar = $TextureProgressBar
# Adjust this path if your label is named differently or nested elsewhere
#@onready var progress_label: Label = get_node_or_null("ProgressLabel") as Label


func _ready():
	# Ensure the loading screen runs even if the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	tip_label.text = "TIP: " + TIPS.pick_random()

	# Initialize TextureProgressBar
	if progress_bar:
		progress_bar.value = 0
		#progress_bar.visible = false # Hide until progress starts

	# Auto-bind to generator signal
	var gen: Node = null
	if generator_path != null and not str(generator_path).is_empty():
		gen = get_node(generator_path)

	if gen == null:
		var root_scene := get_tree().current_scene
		if root_scene == null:
			root_scene = get_tree().root
		gen = _find_generator_with_signal(root_scene)

	if gen != null:
		bind_to_generator(gen)


func _on_timer_timeout():
	display_random_tip()


func display_random_tip():
	var tween = create_tween()
	tween.tween_property(tip_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): tip_label.text = "TIP: " + TIPS.pick_random())
	tween.tween_property(tip_label, "modulate:a", 1.0, 0.5)


# -----------------------------
# Progress handling
# -----------------------------


func _find_generator_with_signal(root: Node) -> Node:
	if root == null:
		return null
	if root.has_signal("generation_progress"):
		return root
	for c in root.get_children():
		var res := _find_generator_with_signal(c)
		if res != null:
			return res
	return null


func bind_to_generator(gen: Node) -> void:
	if gen == null or not gen.has_signal("generation_progress"):
		return

	_last_pct = 0
	_first_progress_received = false

	if progress_bar:
		progress_bar.value = 0

	if not gen.is_connected("generation_progress", _on_gen_progress):
		gen.connect("generation_progress", _on_gen_progress)


func _on_gen_progress(p: float, _text: String) -> void:
	if not _first_progress_received:
		_first_progress_received = true
		if progress_bar:
			progress_bar.visible = true
#		if progress_label: progress_label.visible = true

	set_progress(p, _text)


func set_progress(p: float, _text: String = "") -> void:
	# p is 0.0 - 1.0
	var pct := int(clamp(p * 100.0, 0, 100))

	# Determine if we are actually moving forward
	var is_moving = pct > _last_pct

	if pct < _last_pct and pct != 100:
		pct = _last_pct

	# 1. Update the Bar
	if progress_bar:
		progress_bar.value = pct

	# 2. Update the Character Position
	#if loading_char:
	# We pass the raw float (0.0 - 1.0) for smooth lerping
	#loading_char.set_frame_and_progress(p, is_moving)

	_last_pct = pct

#	if progress_label and not _text.is_empty():
#		progress_label.text = _text
