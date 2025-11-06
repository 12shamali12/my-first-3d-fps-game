extends Node3D

@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer3D

func _ready():
	if music_player:
		music_player.play()
	else:
		print("AudioStreamPlayer not found!")
