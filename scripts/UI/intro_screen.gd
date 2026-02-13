extends Control

# --- Scene Configuration ---
const START_MENU_PACKED := preload("res://scenes/UI/start-menu.tscn")
@export var start_menu_path: String = "res://scenes/UI/start-menu.tscn"

# --- Node References (Ensure these names match your Scene Tree) ---
@onready var logo = $CenterContainer/Label
@onready var logo_container = $CenterContainer
@onready var static_rect = $StaticOverlay
@onready var invert_rect = $InvertLayer
@onready var tv_noise = $tv_noise


func _ready():
	tv_noise.play()
	# 1. Reset everything to "Power Off" state
	logo.modulate.a = 0
	logo.scale = Vector2(1.0, 1.0)

	# Prepare the TV Static (Scale it down to a thin horizontal needle)
	static_rect.visible = true
	static_rect.pivot_offset = static_rect.size / 2
	static_rect.scale = Vector2(1.0, 0.005)
	static_rect.material.set_shader_parameter("noise_intensity", 1.0)

	# Hide the Invert effect
	invert_rect.material.set_shader_parameter("intensity", 0.0)

	# Start the sequence after a tiny delay
	get_tree().create_timer(0.5).timeout.connect(play_intro_sequence)


func play_intro_sequence():
	var tween = create_tween()

	tween.tween_property(self, "modulate:a", 1.0, 0.0)
	tween.tween_interval(0.2)
	# --- STAGE 1: TV POWER ON ---
	# The horizontal line "pops" open vertically
	tween.tween_property(static_rect, "scale:y", 1.0, 1.0).set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_OUT
	)

	# --- STAGE 2: CHANNEL STATIC ---
	# Let the static buzz for a second to build tension
	tween.tween_interval(3.0)

	# --- STAGE 3: THE CHANNEL SWITCH (VERTICAL ROLL) ---
	# A quick "jitter" to simulate the TV tuning into the signal
	tween.tween_callback(
		func():
			var roll_tween = create_tween()
			roll_tween.tween_property(static_rect, "position:y", static_rect.position.y - 50, 0.05)
			roll_tween.tween_property(static_rect, "position:y", static_rect.position.y + 50, 0.05)
			roll_tween.tween_property(static_rect, "position:y", 0, 0.05)
	)
	tween.tween_interval(0.15)

	# --- STAGE 4: THE DOOM SLAM (The Impact) ---
	tween.tween_callback(
		func():
			static_rect.visible = false  # Turn off static instantly

			# Reveal and Slam the Logo
			logo.modulate.a = 1.0
			logo.scale = Vector2(1.6, 1.6)  # Lunge at camera

			# Trigger the "Invert" flash (Flash ON)
			invert_rect.material.set_shader_parameter("intensity", 1.0)

			# Sound and Shake
			#audio_player.play()
			apply_impact_shake(0.4, 25.0)
	)

	# --- STAGE 5: THE SETTLE ---
	# Snap logo back to size and turn off the flash very quickly
	tween.tween_property(logo, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(invert_rect.material, "shader_parameter/intensity", 0.0, 0.15)

	# --- STAGE 6: EXIT TO MENU ---
	tween.tween_interval(2.5)  # Hold the logo on screen
	tween.tween_property(self, "modulate:a", 0.0, 2)  # Fade whole screen to black
	tween.tween_callback(func(): _go_to_start_menu())


func _go_to_start_menu() -> void:
	var scene_tree = get_tree()
	if scene_tree != null:
		scene_tree.change_scene_to_packed(START_MENU_PACKED)
	else:
		push_error("intro_screen: SceneTree is null; cannot change to start menu")


# --- Procedural Effects ---


func apply_impact_shake(duration: float, force: float):
	var s_tween = create_tween()
	# The LogoContainer handles the movement so the Logo can handle its own Scale
	var original_pos = logo_container.position

	# Rapid, decaying random movements
	for i in range(12):
		var offset = Vector2(
			GlobalRNG.randf_range(-force, force), GlobalRNG.randf_range(-force, force)
		)
		s_tween.tween_property(logo_container, "position", original_pos + offset, duration / 12.0)
		force *= 0.8  # Make the shake get smaller over time

	s_tween.tween_property(logo_container, "position", original_pos, 0.05)
