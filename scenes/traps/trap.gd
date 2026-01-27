extends Node2D

@export var damage: int = 2
@export var one_shot: bool = false
@export var cooldown: float = 1.0

@onready var area: Area2D = $Area2D
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _ready_to_trigger := true


func _ready() -> void:
	if area == null:
		push_error("❌ TrapTile: Area2D fehlt!")
		return
	if anim == null:
		push_error("❌ TrapTile: AnimatedSprite2D fehlt!")
		return

	area.body_entered.connect(_on_body_entered)

	# Default Idle
	if anim.sprite_frames != null and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")

	#print("✅ TrapTile ready | dmg:", damage, "| cooldown:", cooldown)


func _on_body_entered(body: Node) -> void:
	if not _ready_to_trigger:
		#print("⏳ Trap trigger blocked (cooldown)")
		return

	if body == null:
		return

	# Nur Player triggern
	if not body.is_in_group("player"):
		#print("ℹ️ Trap ignored:", body.name)
		return

	#print("🔥 TRAP TRIGGERED by:", body.name)

	_ready_to_trigger = false

	# Animation abspielen
	if anim.sprite_frames != null and anim.sprite_frames.has_animation("trigger"):
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

	# zurück auf idle
	if anim.sprite_frames != null and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")

	#print("✅ Trap ready again")


func _apply_damage(player: Node) -> void:
	if player == null:
		return

	# Variante 1: Player hat take_damage()
	if player.has_method("take_damage"):
		player.take_damage(damage)
		#print("💥 Damage applied via take_damage:", damage)
		return

	# Variante 2: Player hat hp Variable
	if "hp" in player:
		player.hp -= damage
		#print("💥 Damage applied via hp--:", damage, "| new hp:", player.hp)
		return

	#print("⚠️ Trap: Player hat weder take_damage() noch hp!")
