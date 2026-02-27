extends Node2D

@export var speed := 0.25
@export var debug_autostart := true

@onready var path_follower: PathFollow2D = $Path2D/PathFollow2D
@onready var cutscene_cam: Camera2D = $Path2D/PathFollow2D/Camera2D
@onready var dialog: Panel = $CanvasLayer/Panel # Pfad anpassen

var player: Node = null
var running := false

func _ready() -> void:
	if debug_autostart:
		start(null) # zum reinen Test ohne Player

func _physics_process(delta: float) -> void:
	if !running:
		return

	path_follower.progress_ratio = clamp(path_follower.progress_ratio + speed * delta, 0.0, 1.0)
	if is_equal_approx(path_follower.progress_ratio, 1.0):
		end()

func start(p: Node) -> void:
	player = p
	running = true

	# Kamera übernehmen
	cutscene_cam.enabled = true
	cutscene_cam.make_current()

	# Player-Kamera deaktivieren (falls Player übergeben wurde)
	if player:
		var player_cam := player.get_node_or_null("Camera2D")
		if player_cam is Camera2D:
			(player_cam as Camera2D).enabled = false

	path_follower.progress_ratio = 0.0

func end() -> void:
	running = false

	# Cutscene-Kamera aus
	cutscene_cam.enabled = false

	# Player-Kamera wiederherstellen
	if player:
		var player_cam := player.get_node_or_null("Camera2D")
		if player_cam is Camera2D:
			(player_cam as Camera2D).enabled = true
			(player_cam as Camera2D).make_current()

	visible = false
	

var dialog_lines := [
	"...Ziemlich düster hier...Was verbirgt sich nur hinter dieser Tür?",
	"Ob du da drin bist? Mir gefällt das nicht, doch ich habe wohl keine Wahl.",
	"Ich bin schon so weit gekommen. Jetzt gibt es kein zurück mehr!"
]

func end_reached() -> void:
	running = false
	dialog.show_lines(dialog_lines)
	dialog.finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)

func _on_dialog_finished() -> void:
	# hier Cutscene beenden, Player-Kamera/Input zurückgeben etc.
	end()
	
	
	
		
