extends Node2D

@onready var tip_label = $TipLabel

var tips: Array = [
	"Torches keep the shadows at bay, but they don't last forever.",
	"Listen closely; some walls sound hollow when struck.",
	"Rare loot is often guarded by the deadliest traps.",
	"Don't forget to pack extra rations for long descents.",
	"Not all monsters are hostile; some just want to trade."
]

func _ready():
	tip_label.text = "TIP: " + tips.pick_random()

func _on_timer_timeout():
	display_random_tip()

func display_random_tip():
	var tween = create_tween()
	
	# 1. Fade out the OLD text
	tween.tween_property(tip_label, "modulate:a", 0.0, 0.5)
	
	# 2. Wait until it's invisible, THEN swap the text
	tween.tween_callback(func(): 
		tip_label.text = "TIP: " + tips.pick_random()
	)
	
	# 3. Fade in the NEW text
	tween.tween_property(tip_label, "modulate:a", 1.0, 0.5)
