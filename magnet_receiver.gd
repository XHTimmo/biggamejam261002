extends Area2D

signal locked
var engaged := false
var reaction_enabled := true

func _ready() -> void:
	queue_redraw()

func iron_hit() -> void:
	if engaged or not reaction_enabled:
		return
	engaged = true
	locked.emit()
	queue_redraw()

func _draw() -> void:
	var tint := Color("#8ce3b5") if engaged else Color("#d4ae67")
	draw_rect(Rect2(-22, -24, 44, 48), Color("#29424e"))
	draw_arc(Vector2(0, -3), 13, 0, PI, 16, tint, 7)
	draw_rect(Rect2(-17, -21, 8, 20), tint)
	draw_rect(Rect2(9, -21, 8, 20), tint)
	if engaged:
		draw_rect(Rect2(-16, -24, 32, 6), Color("#e8eddf"))
