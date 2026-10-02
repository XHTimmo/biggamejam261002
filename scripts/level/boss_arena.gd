extends Node2D

@export var arena_size := Vector2(820.0, 500.0)
@export var tint := Color("#9AF5E5")
var pulse := 0.0

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-arena_size / 2.0, arena_size)
	var alpha := 0.36 + sin(pulse * 3.0) * 0.08
	draw_rect(rect, Color(tint, 0.035), true)
	draw_rect(rect, Color(tint, alpha), false, 3.0)
	draw_line(rect.position + Vector2(0, 28), rect.position + Vector2(arena_size.x, 28), Color(tint, 0.45), 2.0)
	for x in range(int(rect.position.x) + 30, int(rect.end.x), 64):
		var top := Vector2(x, rect.position.y + 8)
		var bottom := Vector2(x + 18, rect.position.y - 22)
		draw_line(top, bottom, Color(tint, 0.48), 2.0)
		draw_circle(bottom, 4.0, Color(tint, 0.7))
	for index in range(5):
		var angle := float(index) * TAU / 5.0 + pulse * 0.35
		var point := Vector2(cos(angle), sin(angle)) * Vector2(arena_size.x * 0.42, arena_size.y * 0.38)
		draw_circle(point, 3.0 + sin(pulse * 5.0 + index) * 1.2, Color(tint, 0.7))
