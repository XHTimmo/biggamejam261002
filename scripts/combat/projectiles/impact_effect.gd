extends Node2D

var tint := Color("#D8FFFF")
var charged := false
var elapsed := 0.0
var duration := 0.30

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var alpha := 1.0 - progress
	var radius := (8.0 if not charged else 13.0) + progress * (24.0 if not charged else 34.0)
	draw_circle(Vector2.ZERO, radius, Color(tint, alpha * 0.12))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(tint, alpha * 0.9), 3.0 if not charged else 5.0)
	for index in range(8):
		var angle := float(index) * TAU / 8.0 + progress * 0.9
		var start := Vector2(cos(angle), sin(angle)) * radius * 0.55
		var finish := Vector2(cos(angle), sin(angle)) * (radius + 10.0 * progress)
		draw_line(start, finish, Color(tint, alpha), 2.0)
