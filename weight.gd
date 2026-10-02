extends RigidBody2D

func _ready() -> void:
	add_to_group("weights")
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-28, -28, 56, 56), Color("#d47f58"), true)
	draw_rect(Rect2(-21, -21, 42, 42), Color("#f2b36a"), true)
	draw_line(Vector2(-15, -15), Vector2(15, 15), Color("#985744"), 4.0)
	draw_line(Vector2(15, -15), Vector2(-15, 15), Color("#985744"), 4.0)

