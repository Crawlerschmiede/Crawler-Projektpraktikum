extends CanvasLayer

var tips: Array = [
	"Torches keep the shadows at bay, but they don't last forever.",
	"Listen closely; some walls sound hollow when struck.",
	"Rare loot is often guarded by the deadliest traps.",
	"Don't forget to pack extra rations for long descents.",
	"Not all monsters are hostile; some just want to trade."
]

@onready var tip_label = $TipLabel

# Progress UI
@export var generator_path: NodePath
@onready var progress_bar: ProgressBar = get_node_or_null("ProgressBar") as ProgressBar
@onready var progress_label: Label = get_node_or_null("ProgressLabel") as Label


func _ready():
	tip_label.text = "TIP: " + tips.pick_random()

	# initialize progress UI
	if progress_bar != null:
		progress_bar.value = 0
	else:
		# try to find a ProgressBar child with common names
		progress_bar = get_node_or_null("ProgressBar") as ProgressBar

	# auto-bind to generator signal
	var gen: Node = null
	if generator_path != null and str(generator_path) != "":
		gen = get_node_or_null(generator_path)
	if gen == null:
		var root_scene := get_tree().get_current_scene()
		if root_scene == null:
			root_scene = get_tree().get_root()
		gen = _find_generator_with_signal(root_scene)
	if gen != null:
		bind_to_generator(gen)


func _on_timer_timeout():
	display_random_tip()


func display_random_tip():
	var tween = create_tween()

	# 1. Fade out the OLD text
	tween.tween_property(tip_label, "modulate:a", 0.0, 0.5)

	# 2. Wait until it's invisible, THEN swap the text
	tween.tween_callback(func(): tip_label.text = "TIP: " + tips.pick_random())

	# 3. Fade in the NEW text
	tween.tween_property(tip_label, "modulate:a", 1.0, 0.5)


# -----------------------------
# Progress handling (bind to generator.generation_progress(p,text))
# -----------------------------
func _find_generator_with_signal(root: Node) -> Node:
	if root == null:
		return null
	if root.has_signal("generation_progress"):
		return root
	for c in root.get_children():
		if c is Node:
			var res := _find_generator_with_signal(c)
			if res != null:
				return res
	return null

func bind_to_generator(gen: Node) -> void:
	if gen == null:
		return
	if not gen.has_signal("generation_progress"):
		return
	if not gen.is_connected("generation_progress", Callable(self, "_on_gen_progress")):
		gen.connect("generation_progress", Callable(self, "_on_gen_progress"))

func _on_gen_progress(p: float, text: String) -> void:
	set_progress(p, text)

func set_progress(p: float, text: String = "") -> void:
	# p is 0.0 - 1.0; ProgressBar expects 0-100
	var pct := int(clamp(p * 100.0, 0, 100))
	if progress_bar != null:
		progress_bar.value = pct
	else:
		# no progress bar present; ignore
		pass

	if progress_label != null and text != "":
		progress_label.text = text
