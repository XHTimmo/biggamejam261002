extends StaticBody2D

var is_open := false

func set_open(value: bool) -> void:
	if is_open == value:
		return
	is_open = value
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", is_open)
	queue_redraw()

func _draw() -> void:
	if is_open:
		return
	for y in range(-64, 65, 16):
		draw_rect(Rect2(-10, y, 20, 12), Color("#7e8ca9"), true)
	draw_line(Vector2(-13, -72), Vector2(-13, 72), Color("#b9d3ee"), 3.0)
	draw_line(Vector2(13, -72), Vector2(13, 72), Color("#b9d3ee"), 3.0)

