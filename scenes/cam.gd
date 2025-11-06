extends Camera3D
@export var target_path: NodePath
var _target: Node3D

func set_target(node: Node) -> void:
	_target = node

func _process(_dt: float) -> void:
	if _target:
		global_transform.origin = _target.global_transform.origin
		# copy facing (optional; comment if you prefer fixed cameras)
		global_transform.basis = _target.global_transform.basis
