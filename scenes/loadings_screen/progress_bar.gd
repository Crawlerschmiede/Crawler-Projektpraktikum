extends ProgressBar

@export var generator_path: NodePath
@onready var bar: ProgressBar = get_node_or_null("ProgressBar") as ProgressBar
@onready var label: Label = get_node_or_null("Label") as Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# If there's no child ProgressBar, maybe this script is attached to the ProgressBar itself
	if bar == null and self is ProgressBar:
		bar = self as ProgressBar

	if bar != null:
		bar.value = 0
	else:
		push_warning("ProgressBar node not found for progress UI; progress updates will be ignored")

	# Try to connect automatically: prefer explicit path, otherwise search scene
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
	if bar != null:
		bar.value = pct
	print("Progress: ", pct)
	if label != null and text != "":
		label.text = text
