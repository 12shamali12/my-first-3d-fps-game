extends AudioStreamPlayer

@export var start_volume_db: float = -20 # 0 = normal volume, -80 = silent
@export var auto_play: bool = true        # Should play automatically on ready

func _ready():
	volume_db = start_volume_db
	if auto_play:
		play()
