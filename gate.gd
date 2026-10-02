extends StaticBody2D

var is_open := false
@export var gate_size := Vector2(24, 144)

func _ready() -> void:
	queue_redraw()

func set_open(value: bool) -> void:
	if is_open == value:
		return
	is_open = value
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", is_open)
	queue_redraw()

func _draw() -> void:
	var half := gate_size / 2
	draw_rect(Rect2(-half - Vector2(5, 0), gate_size + Vector2(10, 0)), Color("#1c303a"), false, 3)
	if is_open:
		draw_circle(Vector2(0, -half.y + 10), 5, Color("#8ce3b5"))
		return
	for y in range(int(-half.y), int(half.y), 16):
		draw_rect(Rect2(-half.x, y, gate_size.x, 12), Color("#728a9b"))
		draw_line(Vector2(-half.x + 3, y + 2), Vector2(half.x - 3, y + 9), Color("#e5b467"), 3)

