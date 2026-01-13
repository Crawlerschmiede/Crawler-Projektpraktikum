extends SubViewport

@onready var player = $"../../../Player"
@onready var cam = $MiniCam


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	world_2d = get_tree().root.world_2d


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	cam.position = player.position
