extends Area2D

signal active_changed(active: bool)
var active := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("weights"):
		call_deferred("_refresh_active")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("weights"):
		call_deferred("_refresh_active")

func _refresh_active() -> void:
	var still_pressed := false
	for other in get_overlapping_bodies():
		if other.is_in_group("weights"):
			still_pressed = true
			break
	_set_active(still_pressed)

func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	active_changed.emit(active)
	queue_redraw()

func _draw() -> void:
	var color := Color("#65d7a0") if active else Color("#416a60")
	draw_rect(Rect2(-54, -7, 108, 14), color, true)
	draw_circle(Vector2.ZERO, 6.0, Color("#f8f0ba"))

