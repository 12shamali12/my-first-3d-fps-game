extends CenterContainer

@export var DOT_RAD: float = 1.0
@export var DOT_C: Color = Color.RED

# Called when the node enters the scene tree for the first time.
func _ready():
	queue_redraw()  # Draw the dot initially

# Called every frame. 'delta' is the elapsed time since the previous frame.
# Draw function (must NOT be inside _process)
func _draw():
	draw_circle(Vector2(0, 0), DOT_RAD, DOT_C)
