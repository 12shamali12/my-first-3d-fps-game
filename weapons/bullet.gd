extends Node3D

const SPEED := 40.0
const DAMAGE := 20   # 5 hits to 100 HP

@onready var mesh: MeshInstance3D      = $MeshInstance3D
@onready var ray: RayCast3D            = $RayCast3D
@onready var particles: GPUParticles3D = $GPUParticles3D
var shooter: Node = null

func set_shooter(p: Node) -> void:
	shooter = p

func _ready() -> void:
	get_tree().create_timer(5.0).timeout.connect(queue_free)
	#mesh.visible= true

func _process(delta: float) -> void:
	position += transform.basis * Vector3(0, 0, -SPEED) * delta
	if ray.is_colliding():
		var c := ray.get_collider()
		if c and c.has_method("take_damage") and c != shooter:
			c.take_damage(DAMAGE)
			if c.has_method("set_last_attacker"):
				c.set_last_attacker(shooter)
		_hit_fx_and_free()

func _hit_fx_and_free() -> void:
	mesh.visible = false
	particles.emitting = true
	ray.enabled = false
	set_process(false)
	await get_tree().create_timer(0.8).timeout
	queue_free()
