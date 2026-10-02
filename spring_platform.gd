extends Area2D

var bounce_lock := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	bounce_lock = maxf(0.0, bounce_lock - delta)

func _on_body_entered(body: Node2D) -> void:
	if bounce_lock > 0.0:
		return
	if body is CharacterBody2D and body.global_position.y < global_position.y + 8.0:
		body.velocity.y = -780.0
		bounce_lock = 0.18
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-64, -8, 128, 16), Color("#d99b4a"), true)
	draw_line(Vector2(-50, 0), Vector2(-38, -13), Color("#ffe59b"), 3.0)
	draw_line(Vector2(-38, -13), Vector2(-26, 0), Color("#ffe59b"), 3.0)
	draw_line(Vector2(-26, 0), Vector2(-14, -13), Color("#ffe59b"), 3.0)
	draw_line(Vector2(-14, -13), Vector2(-2, 0), Color("#ffe59b"), 3.0)
	draw_line(Vector2(-2, 0), Vector2(10, -13), Color("#ffe59b"), 3.0)
	draw_line(Vector2(10, -13), Vector2(22, 0), Color("#ffe59b"), 3.0)
	draw_line(Vector2(22, 0), Vector2(34, -13), Color("#ffe59b"), 3.0)
	draw_line(Vector2(34, -13), Vector2(46, 0), Color("#ffe59b"), 3.0)

