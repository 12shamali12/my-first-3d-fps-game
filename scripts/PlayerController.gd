extends CharacterBody3D

@export var controller_id := 0

const SPEED := 6.0
const SPRINT_MULT := 1.8
const JUMP_VELOCITY := 5.5
const SENS := 2.0
var gravity := 9.8

@export var walk_bob_frequency := 6.0
@export var walk_bob_amplitude := 0.03
@export var idle_bob_frequency := 2.0
@export var idle_bob_amplitude := 0.015
@export var bob_smoothness := 6.0

@export var fire_rate := 0.2
@export var bullet_scene: PackedScene = preload("res://weapons/bullet.tscn")

@export var max_health := 100
var health := max_health
@export var respawn_time := 3.0
@export var max_kills := 3
var kills := 0
var last_attacker: Node = null

@export var spawn_points_parent: NodePath
var _spawn_points: Array[Node3D] = []

signal hit(player_id)
signal killed(killer_id)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var gun_anim: AnimationPlayer = $Head/Camera3D/rifle/AnimationPlayer
@onready var gun_barrel: RayCast3D = $Head/Camera3D/rifle/RayCast3D
@onready var player_mesh: MeshInstance3D = $MeshInstance3D
@onready var death_particles: GPUParticles3D = $DeathParticles44
#@onready var anim_tree: AnimationTree = $AnimationTree
#@onready var playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/State/playback")

var can_shoot := true
var bob_t := 0.0
var head_default := Vector3.ZERO
var _just_jumped := false

func _ready() -> void:
	head_default = head.position
	camera.current = true
	#anim_tree.active = true

	if spawn_points_parent != NodePath():
		var n := get_node_or_null(spawn_points_parent)
		if n:
			for c in n.get_children():
				if c is Node3D:
					_spawn_points.append(c)

func _physics_process(dt: float) -> void:
	if health <= 0: return

	# gravity
	if not is_on_floor():
		velocity.y -= gravity * dt

	# movement (left stick)
	var mv := Vector2(
		Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X),
		-Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_Y)
	)
	if mv.length() < 0.15: mv = Vector2.ZERO

	var f := -head.global_transform.basis.z
	var r :=  head.global_transform.basis.x
	f.y = 0; r.y = 0
	f = f.normalized(); r = r.normalized()

	var dir := (r * mv.x + f * mv.y)
	if dir.length() > 1.0: dir = dir.normalized()

	var spd := SPEED
	var sprinting := Input.is_joy_button_pressed(controller_id, JOY_BUTTON_LEFT_STICK)
	if sprinting: spd *= SPRINT_MULT

	velocity.x = move_toward(velocity.x, dir.x * spd, spd * dt * 5.0)
	velocity.z = move_toward(velocity.z, dir.z * spd, spd * dt * 5.0)

	# jump (A)
	if is_on_floor():
		_just_jumped = false
		if Input.is_joy_button_pressed(controller_id, JOY_BUTTON_A):
			velocity.y = JUMP_VELOCITY
			_just_jumped = true

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

	# look (right stick)
	var lx := Input.get_joy_axis(controller_id, JOY_AXIS_RIGHT_X)
	var ly := Input.get_joy_axis(controller_id, JOY_AXIS_RIGHT_Y)
	if abs(lx) < 0.1: lx = 0
	if abs(ly) < 0.1: ly = 0
	head.rotate_y(-lx * SENS * dt)
	camera.rotate_x(-ly * SENS * dt)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))

	## animation state
	#if health <= 0:
		##_travel_if_exists("fallingBackDeath")
	##elif _just_jumped or (not is_on_floor() and velocity.y > 0.1):
		#_travel_if_exists("jump")
	#elif moving and sprinting:
		#_travel_if_exists("run")
	#elif moving:
		#_travel_if_exists("walk")
	#else:
		#_travel_if_exists("idle")

	# shoot (RT)
	if Input.get_joy_axis(controller_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5 and can_shoot:
		_shoot()

func _shoot() -> void:
	if not can_shoot or health <= 0: return
	can_shoot = false
	if gun_anim and gun_anim.has_animation("shoot"):
		gun_anim.play("shoot")
	#_travel_if_exists("gunplay")

	var b := bullet_scene.instantiate()
	b.global_transform = gun_barrel.global_transform
	get_tree().current_scene.add_child(b)
	if b.has_method("set_shooter"):
		b.set_shooter(self)

	var t := Timer.new()
	t.one_shot = true
	t.wait_time = fire_rate
	add_child(t)
	t.timeout.connect(func(): can_shoot = true)
	t.start()

# ----- Damage / death / respawn -----
func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	emit_signal("hit", 2)
	if health <= 0:
		_die()

func set_last_attacker(attacker: Node) -> void:
	last_attacker = attacker

func _die() -> void:
	#_travel_if_exists("fallingBackDeath")
	$CollisionShape3D.disabled = true
	#$Head/MeshInstance3D.visible = false
	#$Head/Camera3D/rifle/Node2.visible = false
	set_process(false)

	if death_particles:
		death_particles.global_transform = global_transform
		death_particles.one_shot = true
		death_particles.emitting = true

	if last_attacker and last_attacker.has_method("add_kill"):
		last_attacker.add_kill()
	emit_signal("killed", 1)
	last_attacker = null

	await get_tree().create_timer(respawn_time).timeout
	_respawn()

func _respawn() -> void:
	health = max_health
#	$UI._update_hud()
	$CollisionShape3D.disabled = false
	#$Head/MeshInstance3D.visible = true
	#$Head/Camera3D/rifle/Node2.visible = true
	set_process(true)
	if _spawn_points.size() > 0:
		var sp := _spawn_points[randi() % _spawn_points.size()]
		global_transform.origin = sp.global_transform.origin
	velocity = Vector3.ZERO
	#_travel_if_exists("idle")

func add_kill() -> void:
	kills += 1

#func _travel_if_exists(state_name: String) -> void:
#	if playback:
#		playback.travel(state_name)
