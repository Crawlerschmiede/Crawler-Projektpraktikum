extends Node2D

@export var damage: int = 2
@export var one_shot: bool = false
@export var cooldown: float = 1.0
@export var world_index: int = 0

var _ready_to_trigger := true
var _idle_anim_name: String = ""
var _trigger_anim_name: String = ""

@onready var area: Area2D = $Area2D
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if area == null:
		push_error("TrapTile: Area2D fehlt!")
		return

	# select animation node based on world_index and set visibility

	if anim == null:
		push_error("TrapTile: AnimatedSprite2D fehlt!")
		return

	area.body_entered.connect(_on_body_entered)

	# animation names per world: e.g. "idle_world1", "trigger_world1"
	_idle_anim_name = "idle_world%d" % (world_index + 1)
	_trigger_anim_name = "trigger_world%d" % (world_index + 1)

	# ensure sprite visible and play idle if available, otherwise fall back to generic "idle"
	anim.visible = true
	# There is no separate idle animation; idle == first frame.
	# Choose trigger animation (world-specific) if available, otherwise fallback to generic "trigger".
	var chosen_trigger: String = ""
	if anim.sprite_frames != null and anim.sprite_frames.has_animation(_trigger_anim_name):
		chosen_trigger = _trigger_anim_name
	elif anim.sprite_frames != null and anim.sprite_frames.has_animation("trigger"):
		chosen_trigger = "trigger"

	if chosen_trigger != "":
		# set animation to the trigger animation but stop playing and show first frame (idle)
		anim.animation = chosen_trigger
		anim.stop()
		anim.frame = 0
	else:
		# no trigger animation available; just ensure frame 0
		anim.stop()
		anim.frame = 0

	print("TrapTile ready | dmg:", damage, "| cooldown:", cooldown)


func _on_body_entered(body: Node) -> void:
	if not _ready_to_trigger:
		print("Trap trigger blocked (cooldown)")
		return

	if body == null:
		return

	# Nur Player triggern
	if not body.is_in_group("player"):
		print("Trap ignored:", body.name)
		return

	print("TRAP TRIGGERED by:", body.name)

	_ready_to_trigger = false

	# Animation abspielen (welt-spezifisch mit Fallback)
	if anim.sprite_frames != null and anim.sprite_frames.has_animation(_trigger_anim_name):
		anim.play(_trigger_anim_name)
	elif anim.sprite_frames != null and anim.sprite_frames.has_animation("trigger"):
		anim.play("trigger")

	# Schaden machen
	_apply_damage(body)

	# one shot?
	if one_shot:
		#print("💀 Trap one_shot -> removed")
		queue_free()
		return

	# cooldown reset
	if cooldown > 0:
		await get_tree().create_timer(cooldown).timeout

	_ready_to_trigger = true

	# zurück auf idle == erster Frame
	# Wenn zuvor eine trigger-Animation gewählt wurde, setze wieder Frame 0 und stoppe die Animation
	anim.stop()
	anim.frame = 0

	#print("✅ Trap ready again")


func _apply_damage(player: Node) -> void:
	if player == null:
		return

	# Variante 1: Player hat take_damage()
	if player.has_method("take_damage"):
		player.take_damage(damage, "undodgeable")
		#print("💥 Damage applied via take_damage:", damage)
		return
