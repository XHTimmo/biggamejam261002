extends StaticBody2D

@export var size := Vector2(160, 24)
@export var tint := Color("#2e4953")

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-size / 2, size)
	draw_rect(rect, tint)
	draw_line(rect.position, rect.position + Vector2(size.x, 0), Color("#8dadac"), 3)
	if size.y >= 20:
		for x in range(int(-size.x / 2) + 8, int(size.x / 2), 40):
			draw_rect(Rect2(x, -size.y / 2 + 7, 22, 3), tint.lightened(0.12))
		draw_line(Vector2(-size.x / 2, size.y / 2), size / 2, tint.darkened(0.35), 3)
