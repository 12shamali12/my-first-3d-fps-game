extends Control

@export var player: NodePath   # Assign the Player node in Inspector
@onready var crosshair = $Rectile  # The crosshair TextureRect/ColorRect

func _process(_delta):
	if not player:
		return

	# Resolve NodePath to Node
	var player_node = get_node(player)
	if not player_node:
		return

	# Get the gun RayCast3D
	var rifle = player_node.get_node_or_null("Rifle")
	if not rifle:
		return
	var gun = rifle.get_node_or_null("RayCast3D")
	if not gun:
		return

	# Get the player camera
	var cam = player_node.get_node_or_null("Camera3D") as Camera3D
	if not cam:
		return

	# Project a point far ahead along the gun direction
	var ray_target = gun.global_transform.origin + -gun.global_transform.basis.z * 1000

	# Convert 3D point to 2D screen coordinates
	var screen_pos = cam.unproject_position(ray_target)

	# Center the crosshair
	crosshair.rect_position = screen_pos - crosshair.rect_size / 2
