extends CharacterBody3D

@export var player_id := 2
@export var is_keyboard_player := false
@export var controller_id := 0
@export var player_name := "Player 2"

@export var respawn_a: NodePath
@export var respawn_b: NodePath
@export var opponent_path: NodePath

signal hit(player_id)
signal killed(killer_id)

const SPEED := 6.0
const SPRINT_MULT := 1.8
const JUMP := 5.5
const SENS := 0.6
const GRAV := 9.8

@onready var head: Node3D = $Head
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var gun_barrel: RayCast3D = $Head/GunBarrel
@export var bullet_scene: PackedScene = preload("res://weapons/bullet.tscn")

var can_shoot := true
@export var fire_rate := 0.25

var hearts := 5
var last_attacker: Node = null
var dead := false

func _physics_process(delta: float) -> void:
	if dead: return
	if is_keyboard_player:
		_handle_keyboard(delta)
	else:
		_handle_controller(delta)
	if not is_on_floor():
		velocity.y -= GRAV * delta
	move_and_slide()

func _handle_keyboard(delta: float) -> void:
	var f := -head.global_transform.basis.z
	var r :=  head.global_transform.basis.x
	f.y = 0; r.y = 0
	f = f.normalized(); r = r.normalized()

	var dir := Vector3.ZERO
	if Input.is_action_pressed("p2_forward"): dir += f
	if Input.is_action_pressed("p2_back"):    dir -= f
	if Input.is_action_pressed("p2_right"):   dir += r
	if Input.is_action_pressed("p2_left"):    dir -= r
	if dir != Vector3.ZERO: dir = dir.normalized()

	var speed := SPEED
	if Input.is_action_pressed("p2_sprint"): speed *= SPRINT_MULT
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if is_on_floor() and Input.is_action_just_pressed("p2_jump"):
		velocity.y = JUMP
		_play_if_exists("animation_jumping")

	var md := Input.get_last_mouse_velocity()
	var yaw := -md.x * SENS * delta
	var pitch := -md.y * SENS * delta
	head.rotate_y(yaw)
	head.rotation.x = clamp(head.rotation.x + pitch, deg_to_rad(-60), deg_to_rad(60))

	#if dir.length() > 0.01: _play_if_exists("animation_moving") else: if anim: anim.stop()

	if Input.is_action_pressed("p2_shoot") and can_shoot:
		_shoot()

func _handle_controller(delta: float) -> void:
	var mv := Vector2(Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X),
		-Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_Y))
	var look_x := Input.get_joy_axis(controller_id, JOY_AXIS_RIGHT_X)
	var look_y := Input.get_joy_axis(controller_id, JOY_AXIS_RIGHT_Y)

	var f := -head.global_transform.basis.z
	var r :=  head.global_transform.basis.x
	f.y = 0; r.y = 0
	f = f.normalized(); r = r.normalized()

	var move_dir := (r * mv.x + f * mv.y)
	if move_dir != Vector3.ZERO: move_dir = move_dir.normalized()

	var speed := SPEED
	if Input.is_joy_button_pressed(controller_id, JOY_BUTTON_LEFT_STICK): speed *= SPRINT_MULT
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	if is_on_floor() and Input.is_joy_button_pressed(controller_id, JOY_BUTTON_A):
		velocity.y = JUMP
		_play_if_exists("animation_jumping")

	head.rotate_y(-look_x * SENS * delta)
	head.rotation.x = clamp(head.rotation.x - look_y * SENS * delta, deg_to_rad(-60), deg_to_rad(60))

	if Input.get_joy_axis(controller_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5 and can_shoot:
		_shoot()

func _play_if_exists(a: String) -> void:
	if anim and anim.has_animation(a):
		if anim.current_animation != a:
			anim.play(a)

func _shoot() -> void:
	if not can_shoot or dead: return
	can_shoot = false
	_play_if_exists("animation_firing")

	var b := bullet_scene.instantiate()
	var xform: Transform3D
	if has_node("Head/GunBarrel"):
		xform = ($Head/GunBarrel as RayCast3D).global_transform
	elif has_node("Head/Camera3D"):
		xform = ($Head/Camera3D as Camera3D).global_transform
	else:
		xform = global_transform
	b.global_transform = xform
	if b.has_method("set_shooter"): b.set_shooter(self)
	get_tree().current_scene.add_child(b)

	var t := Timer.new()
	t.one_shot = true
	t.wait_time = fire_rate
	add_child(t)
	t.timeout.connect(_reset_shoot)
	t.start()

func _reset_shoot() -> void:
	can_shoot = true

func set_last_attacker(a: Node) -> void:
	last_attacker = a

func take_damage(_amount: int) -> void:
	if dead: return
	hearts = max(0, hearts - 1)
	emit_signal("hit", player_id)
	if hearts <= 0:
		_die()

func _die() -> void:
	dead = true
	_play_if_exists("animation_dying")
	var killer_id := 0
	if is_instance_valid(last_attacker) and last_attacker.has_method("get_player_id"):
		killer_id = last_attacker.get_player_id()
	emit_signal("killed", killer_id)
	await get_tree().create_timer(1.2).timeout
	hearts = 5
	dead = false

func get_player_id() -> int:
	return player_id
