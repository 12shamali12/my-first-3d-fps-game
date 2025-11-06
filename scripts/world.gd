extends Node3D

@onready var spawnA: Node3D = $spawnA if has_node("spawnA") else null
@onready var spawnB: Node3D = $spawnB if has_node("spawnB") else null

@onready var vp1: SubViewport = $GridContainer/SubViewportContainer1/SubViewport
@onready var vp2: SubViewport = $GridContainer/SubViewportContainer2/SubViewport

@onready var ui: Control = $UI

@onready var player1: Node = $GridContainer/SubViewportContainer1/SubViewport/player1
@onready var player2: Node = $GridContainer/SubViewportContainer2/SubViewport/player2

func _ready() -> void:
	if not ui.start_game.is_connected(_on_ui_start_game):
		ui.start_game.connect(_on_ui_start_game)
	_connect_player_signals()

func _connect_player_signals() -> void:
	if player1 and player1.has_signal("hit"):
		if not player1.hit.is_connected(_on_p1_hit):
			player1.hit.connect(_on_p1_hit)
	if player2 and player2.has_signal("hit"):
		if not player2.hit.is_connected(_on_p2_hit):
			player2.hit.connect(_on_p2_hit)

	if player1 and player1.has_signal("killed"):
		if not player1.killed.is_connected(_on_p1_killed):
			player1.killed.connect(_on_p1_killed)
	if player2 and player2.has_signal("killed"):
		if not player2.killed.is_connected(_on_p2_killed):
			player2.killed.connect(_on_p2_killed)

	# NEW: listen for respawns to reset hearts in UI
	if player1 and player1.has_signal("respawned"):
		if not player1.respawned.is_connected(_on_p1_respawned):
			player1.respawned.connect(_on_p1_respawned)
	if player2 and player2.has_signal("respawned"):
		if not player2.respawned.is_connected(_on_p2_respawned):
			player2.respawned.connect(_on_p2_respawned)

func _on_ui_start_game(p1_name: String, p2_name: String) -> void:
	if spawnA and player1:
		player1.global_transform.origin = spawnA.global_transform.origin
	if spawnB and player2:
		player2.global_transform.origin = spawnB.global_transform.origin

func _on_p1_hit(_id = 1) -> void: ui.player_hit(1)
func _on_p2_hit(_id = 2) -> void: ui.player_hit(2)

func _on_p1_killed(killer_id: int) -> void:
	if killer_id == 2: ui.player_killed(2)

func _on_p2_killed(killer_id: int) -> void:
	if killer_id == 1: ui.player_killed(1)

# NEW: when a player respawns, reset their hearts on the HUD
func _on_p1_respawned(_id := 1) -> void:
	ui.reset_hearts(1)

func _on_p2_respawned(_id := 2) -> void:
	ui.reset_hearts(2)
