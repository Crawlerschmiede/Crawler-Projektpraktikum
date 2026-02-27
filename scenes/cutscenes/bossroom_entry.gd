extends Node2D

@export var move_duration := 4.0

@onready var path_follower: PathFollow2D = $Path2D/PathFollow2D
@onready var cutscene_cam: Camera2D = $Path2D/PathFollow2D/Camera2D
@onready var dialog_box = $DialogLayer/Control/DialogBox

var player: Node = null

var dialog_lines : Array[String]= [
	"Ist das etwa... eine Tür?",
	"Ich habe überall gesucht, ohne Erfolg.",
	"Bist du vielleicht hier reingelaufen?  Ich habe kein gutes Gefühl..",
	"Ich bin so weit gekommen. Ich kann jetzt nicht aufgeben!"
]

func _ready() -> void:
	# Nur für Testzwecke automatisch starten:
	start_cutscene(null)


func start_cutscene(p: Node) -> void:
	player = p

	# Kamera übernehmen
	cutscene_cam.enabled = true
	cutscene_cam.make_current()

	# Player-Kamera deaktivieren (falls vorhanden)
	if player:
		var player_cam := player.get_node_or_null("Camera2D")
		if player_cam is Camera2D:
			player_cam.enabled = false

	# Bewegung starten
	path_follower.progress_ratio = 0.0

	var tween = create_tween()
	tween.tween_property(
		path_follower,
		"progress_ratio",
		1.0,
		move_duration
	)\
	.set_trans(Tween.TRANS_SINE)\
	.set_ease(Tween.EASE_IN_OUT)

	await tween.finished
	end_reached()


func end_reached() -> void:
	# Dialog anzeigen
	dialog_box.show_lines(dialog_lines)

	# Warten bis Dialog fertig
	await dialog_box.finished

	end_cutscene()


func end_cutscene() -> void:
	# Cutscene-Kamera deaktivieren
	cutscene_cam.enabled = false

	# Player-Kamera wieder aktivieren
	if player:
		var player_cam := player.get_node_or_null("Camera2D")
		if player_cam is Camera2D:
			player_cam.enabled = true
			player_cam.make_current()

	queue_free() # Cutscene entfernen
