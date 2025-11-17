extends CharacterBody3D

# ===== Movement tuning =====
const SPEED := 6.0
const SPRINT_MULT := 1.8
const JUMP_VELOCITY := 5.5
@export var mouse_sens := 0.002
var gravity := 9.8

# ===== Bob tuning (optional) =====
@export var walk_bob_frequency := 6.0
@export var walk_bob_amplitude := 0.03
@export var idle_bob_frequency := 2.0
@export var idle_bob_amplitude := 0.015
@export var bob_smoothness := 6.0

# ===== Combat =====
@export var fire_rate := 0.2
@export var bullet_scene: PackedScene = preload("res://weapons/bullet.tscn")

# ===== Health / Kills =====
@export var max_health := 100
var health := max_health
@export var respawn_time := 3.0
@export var max_kills := 3
var kills := 0
var last_attacker: Node = null

# ===== Respawn points =====
@export var spawn_points_parent: NodePath
var _spawn_points: Array[Node3D] = []

# ===== Signals =====
signal hit(player_id)
signal killed(killer_id)
signal respawned(player_id)
# ===== Nodes =====
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var gun_anim: AnimationPlayer = $Head/Camera3D/rifle/AnimationPlayer
@onready var gun_barrel: RayCast3D = $Head/Camera3D/rifle/RayCast3D
@onready var player_mesh: MeshInstance3D = $Head/MeshInstance3D
@onready var death_particles: GPUParticles3D = $DeathParticles1
@onready var anim_tree: AnimationTree = $Head/AuxScene2/AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/State/playback")

# ===== Internals =====
var can_shoot := true
var bob_t := 0.0
var head_default := Vector3.ZERO
var _just_jumped := false

func _ready() -> void:
	head_default = head.position
	camera.current = true
	anim_tree.active = true
	_travel_if_exists("gunplay")
	

	# collect respawn markers (optional)
	if spawn_points_parent != NodePath():
		var n := get_node_or_null(spawn_points_parent)
		if n:
			for c in n.get_children():
				if c is Node3D:
					_spawn_points.append(c)

func _physics_process(dt: float) -> void:
	if health <= 0: return

	# mouse look
	var mm: Vector2 = Input.get_last_mouse_velocity()
	var dx: float = -mm.x * mouse_sens * dt
	var dy: float = -mm.y * mouse_sens * dt
	head.rotate_y(dx)
	
	
	camera.rotation.x = clamp(camera.rotation.x + dy, deg_to_rad(-60), deg_to_rad(60))

	# gravity
	if not is_on_floor():
		velocity.y -= gravity * dt

	# movement
	var f := -head.global_transform.basis.z
	var r :=  head.global_transform.basis.x
	f.y = 0; r.y = 0
	f = f.normalized(); r = r.normalized()

	var dir := Vector3.ZERO
	if Input.is_action_pressed("p1_forward"): dir += f
	if Input.is_action_pressed("p1_back"):    dir -= f
	if Input.is_action_pressed("p1_right"):   dir += r
	if Input.is_action_pressed("p1_left"):    dir -= r
	if dir != Vector3.ZERO: dir = dir.normalized()

	var spd := SPEED
	var sprinting := Input.is_action_pressed("p1_sprint")
	if sprinting: spd *= SPRINT_MULT

	velocity.x = move_toward(velocity.x, dir.x * spd, spd * dt * 5.0)
	velocity.z = move_toward(velocity.z, dir.z * spd, spd * dt * 5.0)

	# jump
	if is_on_floor():
		_just_jumped = false
		if Input.is_action_just_pressed("p1_jump"):
			velocity.y = JUMP_VELOCITY
			_just_jumped = true
	else:
		# still ascending? keep jump state
		pass

	move_and_slide()

	# head bob
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1 and is_on_floor()
	var freq := walk_bob_frequency if moving else idle_bob_frequency
	var amp := walk_bob_amplitude if moving else idle_bob_amplitude
	bob_t += dt * freq
	var vb := sin(bob_t * TAU) * amp
	var sb := sin(bob_t * PI) * amp * 0.3
	var target := head_default + Vector3(sb, vb, 0)
	head.position = head.position.lerp(target, dt * bob_smoothness)

	# animation state
	if health <= 0:
		_travel_if_exists("fallingBackDeath")
	elif _just_jumped or (not is_on_floor() and velocity.y > 0.1):
		_travel_if_exists("jump")
	elif moving and sprinting:
		_travel_if_exists("RunForward")
	elif moving:
		_travel_if_exists("walk")
	#else:
		#_travel_if_exists("idle")

	# shooting (hold mouse or click)
	if Input.is_action_pressed("p1_shoot") and can_shoot:
		_shoot()

func _shoot() -> void:
	if not can_shoot or health <= 0: return
	can_shoot = false

	if gun_anim and gun_anim.has_animation("shoot"):
		gun_anim.play("shoot")
	_travel_if_exists("gunplay")

	var b := bullet_scene.instantiate()
	b.global_transform = gun_barrel.global_transform
	get_tree().current_scene.add_child(b)
	if b.has_method("set_shooter"):
		b.set_shooter(self)

	var t := Timer.new()
	t.one_shot = true
	t.wait_time = fire_rate
	add_child(t)
	t.timeout.connect(func():
		can_shoot = true
		# after a shot, fall back to locomotion state next physics tick
	)
	t.start()

# ----- Damage / death / respawn -----
func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	emit_signal("hit", 1)
	if health <= 0:
		_die()

func set_last_attacker(attacker: Node) -> void:
	last_attacker = attacker

func _die() -> void:
	_travel_if_exists("fallingBackDeath")
	$CollisionShape3D.disabled = true
	$Head/AuxScene2.visible =false
	#$Head/AuxScene2/Camera3D/rifle/Node2.visible=false 
	set_process(false)

	if death_particles:
		death_particles.global_transform = global_transform
		death_particles.one_shot = true
		death_particles.emitting = true

	if last_attacker and last_attacker.has_method("add_kill"):
		last_attacker.add_kill()
	emit_signal("killed", 2)
	last_attacker = null

	await get_tree().create_timer(respawn_time).timeout
	_respawn()

func _respawn() -> void:
	health = max_health
	emit_signal("respawned",1)
	$Head/AuxScene2.visible=true
	#$Head/AuxScene2/Camera3D/rifle/Node2.visible=true 
	$CollisionShape3D.disabled = false
	#$UI._update_hud()
	set_process(true)
	# pick random spawn if available
	if _spawn_points.size() > 0:
		var sp := _spawn_points[randi() % _spawn_points.size()]
		global_transform.origin = sp.global_transform.origin
	velocity = Vector3.ZERO
	_travel_if_exists("idle")

# ----- Kills API -----
func add_kill() -> void:
	kills += 1

# ----- Helpers -----
func _travel_if_exists(state_name: String) -> void:
	if playback:
		# avoid errors if state missing
		#var states: Array = anim_tree.get("parameters/State/nodes")
		# 'nodes' exists only in editor; at runtime we just try-catch with travel
		playback.travel(state_name)
