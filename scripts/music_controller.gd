extends Node

@export var music_stream: AudioStream       # assign your .ogg or .wav file in Inspector
@export var volume_db: float = -3.0         # volume in decibels (0 = normal, -10 = quieter)
@export var loop: bool = true               # should music loop

var music_player: AudioStreamPlayer = null

func _ready():
	# Try to find an existing AudioStreamPlayer child, or create one
	if has_node("AudioStreamPlayer"):
		music_player = $AudioStreamPlayer
	else:
		music_player = AudioStreamPlayer.new()
		add_child(music_player)

	# Setup player
	music_player.stream = music_stream
	music_player.volume_db = volume_db

	# Check if "Music" bus exists; otherwise, use "Master"
	if AudioServer.get_bus_index("Music") != -1:
		music_player.bus = "Music"
	else:
		music_player.bus = "Master"

	music_player.autoplay = false

	# Enable looping if supported
	if loop and music_stream and "loop" in music_stream:
		music_stream.loop = true

	# Start playing
	if music_stream:
		music_player.play()
	else:
		push_warning("No music assigned to 'music_stream' export variable!")
