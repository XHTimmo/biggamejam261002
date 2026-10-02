extends Area2D

var bounce_lock := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	bounce_lock = maxf(0.0, bounce_lock - delta)
	if bounce_lock > 0.0:
		return
	for body in get_overlapping_bodies():
		if _try_bounce(body):
			return

func _on_body_entered(body: Node2D) -> void:
	if bounce_lock > 0.0:
		return
	_try_bounce(body)

func _try_bounce(body: Node2D) -> bool:
	if body is CharacterBody2D and body.global_position.y < global_position.y + 8.0 and body.velocity.y >= 0:
		if body.has_method("spring_launch"):
			body.spring_launch(-780.0)
		else:
			body.velocity.y = -780.0
		bounce_lock = 0.18
		queue_redraw()
		return true
	return false

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

