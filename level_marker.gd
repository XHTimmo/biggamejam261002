extends Area2D

signal activated(marker: Area2D)

@export var kind := "checkpoint"
@export var marker_id := ""
var used := false
var pulse := 0.0

func _ready() -> void:
	monitoring = true
	body_entered.connect(_entered)

func _entered(body: Node2D) -> void:
	if used or not body.is_in_group("player"):
		return
	if kind != "exit":
		used = true
	activated.emit(self)
	queue_redraw()

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var tint := Color("#76dbc0") if used else Color("#e7b970")
	if kind == "sample":
		if used:
			return
		var bob := sin(pulse * 3) * 4
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -14 + bob), Vector2(10, bob), Vector2(0, 14 + bob), Vector2(-10, bob)
		]), Color("#a8e6e4"))
		draw_circle(Vector2(0, bob), 4, Color("#e9fff5"))
	elif kind == "exit":
		draw_rect(Rect2(-25, -54, 50, 108), Color("#1a4140"))
		draw_rect(Rect2(-19, -46, 38, 92), Color("#8ee4cb"), false, 3)
		draw_line(Vector2(-8, 0), Vector2(10, 0), Color("#e8fbee"), 3)
		draw_line(Vector2(10, 0), Vector2(3, -8), Color("#e8fbee"), 3)
		draw_line(Vector2(10, 0), Vector2(3, 8), Color("#e8fbee"), 3)
	else:
		draw_rect(Rect2(-19, -30, 38, 56), Color("#213b49"))
		draw_rect(Rect2(-14, -24, 28, 22), tint)
		draw_line(Vector2(-8, 12), Vector2(8, 12), tint, 3)
		draw_line(Vector2(0, 4), Vector2(0, 20), tint, 3)
		draw_circle(Vector2(0, -44), 5 + sin(pulse * 2), tint)
