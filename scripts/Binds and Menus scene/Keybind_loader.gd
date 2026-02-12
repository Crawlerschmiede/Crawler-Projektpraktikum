extends VBoxContainer

@onready var scroll_container = %ScrollContainer
@onready var grid = %GridContainer

func _ready():
	# Optional: Hide the horizontal scrollbar for a cleaner look
	if scroll_container:
		scroll_container.custom_minimum_size.x = 198
		scroll_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		display_all_custom_binds()
	else:
		print("Path Error: Check the node order in your Scene Tree!")

func display_all_custom_binds():
	for child in grid.get_children():
		child.queue_free()
		
	var all_actions = InputMap.get_actions()
	print("Found ", all_actions.size(), " total actions.") # DEBUG 1

	for action in all_actions:
		# Temporarily comment out the filter to see EVERYTHING
		if action.begins_with("ui_"): continue
			
		print("Adding action to UI: ", action) # DEBUG 2
		
		var name_label = Label.new()
		name_label.text = action.capitalize()
		name_label.add_theme_color_override("font_color", Color("#42242c"))
		name_label.add_theme_font_override("font", load("uid://d4fqcjicieold"))
		grid.add_child(name_label)
		
		var key_label = Label.new()
		var events = InputMap.action_get_events(action)
		key_label.text = events[0].as_text() if events.size() > 0 else "---"
		key_label.add_theme_color_override("font_color", Color("#42242c"))
		key_label.add_theme_font_override("font", load("uid://d4fqcjicieold"))
		grid.add_child(key_label)
		
		#if events.size() > 0:
		#	key_label.text = events[0].as_text().replace("- Physical", "")
		#else:
		#	key_label.text = "---"
			
		key_label.add_theme_color_override("font_color", Color("#42242c"))
		# Align keys to the right for a "menu" feel
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(key_label)
