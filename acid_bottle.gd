extends Area2D

var direction := Vector2.RIGHT
var speed := 620.0
var lifetime := 1.6

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	lifetime -= delta
	rotation += delta * 8.0
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("acid_hit"):
		body.acid_hit()
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color("#8ce3b5"))
	draw_rect(Rect2(-4, -13, 8, 6), Color("#c9f7de"), true)
	draw_line(Vector2(-5, 3), Vector2(4, -4), Color(1.0, 1.0, 1.0, 0.7), 2.0)

