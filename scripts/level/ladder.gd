extends Area2D

@export var ladder_height := 220.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_ladder"):
		body.set_ladder(self, true)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_ladder"):
		body.set_ladder(self, false)


func _draw() -> void:
	var half := ladder_height / 2
	draw_line(Vector2(-14, -half), Vector2(-14, half), Color("#8ea9c4"), 5.0)
	draw_line(Vector2(14, -half), Vector2(14, half), Color("#8ea9c4"), 5.0)
	for y in range(int(-half) + 12, int(half), 24):
		draw_line(Vector2(-14, y), Vector2(14, y), Color("#d2e1ef"), 4.0)
