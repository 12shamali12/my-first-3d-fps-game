extends Control
signal start_game(p1_name: String, p2_name: String)

@onready var bg_rect: TextureRect         = $Background
@onready var bg_video: VideoStreamPlayer  = $BackgroundVideo

@onready var start_menu: Control          = $StartMenu
@onready var p1_input: LineEdit           = $StartMenu/MarginContainer/MarginContainer/P1Name
@onready var p2_input: LineEdit           = $StartMenu/MarginContainer/MarginContainer2/P2Name
@onready var start_button: Button         = $StartMenu/head/Button

@onready var countdown: Label             = $CountDown
@onready var hud: Control                 = $HUD
@onready var p1_label: Label              = $HUD/TopBar/IDK
@onready var p2_label: Label              = $HUD/TopBar/P2Label

@onready var win_screen: Control          = $WinScreen
@onready var winner_label: Label          = $WinScreen/MarginContainer/WinnerLabel
@onready var rematch_button: Button       = $WinScreen/MarginContainer/Rematch

var p1_name := "Player 1"
var p2_name := "Player 2"
var p1_hearts := 5
var p2_hearts := 5
var p1_kills := 0
var p2_kills := 0
var game_started := false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	await get_tree().process_frame
	var tex := bg_video.get_video_texture()
	if tex:
		bg_rect.texture = tex

	countdown.visible = false
	hud.visible = false
	win_screen.visible = false

	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not rematch_button.pressed.is_connected(_on_rematch_pressed):
		rematch_button.pressed.connect(_on_rematch_pressed)

func _on_start_pressed() -> void:
	p1_name = (p1_input.text if p1_input.text != "" else "Player 1")
	p2_name = (p2_input.text if p2_input.text != "" else "Player 2")
	start_menu.visible = false
	await _start_countdown()
	hud.visible = true
	game_started = true
	_update_hud()

func _start_countdown() -> void:
	countdown.visible = true
	bg_video.stop()
	bg_rect.visible = false
	bg_video.visible = false

	for i in [3, 2, 1]:
		countdown.text = str(i)
		await get_tree().create_timer(1.0).timeout

	countdown.visible = false
	hud.visible = true
	game_started = true
	_update_hud()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("start_game", p1_name, p2_name)

func _on_rematch_pressed() -> void:
	win_screen.visible = false
	hud.visible = false
	p1_hearts = 5
	p2_hearts = 5
	p1_kills = 0
	p2_kills = 0
	await _start_countdown()
	hud.visible = true
	game_started = true

func _update_hud() -> void:
	p1_label.text = "%s  ❤x%d   Kills: %d" % [p1_name, p1_hearts, p1_kills]
	p2_label.text = "%s  ❤x%d   Kills: %d" % [p2_name, p2_hearts, p2_kills]

# === public helpers the World can call ===
func player_hit(player: int) -> void:
	if player == 1:
		p1_hearts = max(0, p1_hearts - 1)
	elif player == 2:
		p2_hearts = max(0, p2_hearts - 1)
	_update_hud()
	_check_win()

func player_killed(killer: int) -> void:
	if killer == 1:
		p1_kills += 1
	elif killer == 2:
		p2_kills += 1
	_update_hud()
	_check_win()

# NEW: reset hearts for a specific player (called on respawn)
func reset_hearts(player: int) -> void:
	if player == 1:
		p1_hearts = 5
	elif player == 2:
		p2_hearts = 5
	_update_hud()
	

func _check_win() -> void:
	if p1_kills >= 3 or p2_kills >= 3:
		var winner := p1_name if p1_kills > p2_kills else p2_name
		_show_winner(winner)

func _show_winner(winner_text: String) -> void:
	game_started = false
	hud.visible = false
	win_screen.visible = true
	winner_label.text = "%s wins!\n%d - %d" % [winner_text, p1_kills, p2_kills]
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
